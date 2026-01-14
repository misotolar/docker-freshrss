FROM php:8.4-fpm-alpine3.23

LABEL org.opencontainers.image.url="https://github.com/misotolar/docker-freshrss"
LABEL org.opencontainers.image.description="FreshRSS Alpine Linux FPM image"
LABEL org.opencontainers.image.authors="Michal Sotolar <michal@sotolar.com>"

ENV FRESHRSS_VERSION=1.28.0
ARG SHA256=2b2826c5b599dbd9031ee3b0329f8df41412d465a0da9dff077f95ce5e81f183
ADD https://github.com/FreshRSS/FreshRSS/archive/refs/tags/$FRESHRSS_VERSION.tar.gz /usr/src/freshrss.tar.gz

ENV FRESHRSS_EXTENSIONS_VERSION=42c32bfd9af2d816933cf310e24d25888a8e167d
ARG FRESHRSS_EXTENSIONS_SHA256=83acdd151631996286ce2f37131c72c060d0545d4dd03b949ad9ec5f0f506542
ADD https://github.com/FreshRSS/Extensions/archive/$FRESHRSS_EXTENSIONS_VERSION.tar.gz /usr/src/extensions.tar.gz

ENV TZ=UTC
ENV PHP_FPM_POOL=www
ENV PHP_FPM_LISTEN=0.0.0.0:9000
ENV PHP_MAX_EXECUTION_TIME=300
ENV PHP_MEMORY_LIMIT=32M
ENV DATA_PATH=/usr/local/freshrss/data

WORKDIR /usr/local/freshrss

RUN set -ex; \
    apk add --no-cache \
        bash \
        gettext-envsubst \
        icu-data-full \
        rsync \
        tzdata \
    ; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        gmp-dev \
        icu-dev \
        libzip-dev \
        openssl-dev \
        postgresql-dev \
    ; \
    docker-php-ext-install -j "$(nproc)" \
        gmp \
        intl \
        opcache \
        pgsql \
        pdo_mysql \
        pdo_pgsql \
        zip \
    ; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .freshrss-rundeps $runDeps; \
    apk del --no-network .build-deps; \
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    { \
        echo 'session.cookie_httponly=1'; \
        echo 'session.use_strict_mode=1'; \
    } > $PHP_INI_DIR/conf.d/session-strict.ini; \
    \
    { \
        echo 'session.auto_start=off'; \
        echo 'session.gc_maxlifetime=21600'; \
        echo 'session.gc_divisor=500'; \
        echo 'session.gc_probability=1'; \
    } > $PHP_INI_DIR/conf.d/session-defaults.ini; \
    \
    { \
        echo 'expose_php=off'; \
        echo 'allow_url_fopen=off'; \
        echo 'date.timezone=${TZ}'; \
        echo 'max_input_vars=10000'; \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
    } > $PHP_INI_DIR/conf.d/freshrss-defaults.ini; \
	echo "$SHA256 */usr/src/freshrss.tar.gz" | sha256sum -c -; \
	echo "$FRESHRSS_EXTENSIONS_SHA256 */usr/src/extensions.tar.gz" | sha256sum -c -; \
    rm -rf \
        /usr/src/php.tar.xz \
        /usr/src/php.tar.xz.asc \
        /var/cache/apk/* \
        /var/tmp/* \
        /tmp/*

COPY resources/php-fpm.conf /usr/local/etc/php-fpm.conf.docker
COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY resources/exclude.txt /usr/src/freshrss.exclude

VOLUME /usr/local/freshrss/data
VOLUME /usr/local/freshrss/html/p

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
