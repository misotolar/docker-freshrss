FROM php:8.4-fpm-alpine3.21

LABEL org.opencontainers.image.url="https://github.com/misotolar/docker-freshrss"
LABEL org.opencontainers.image.description="FreshRSS Alpine Linux FPM image"
LABEL org.opencontainers.image.authors="Michal Sotolar <michal@sotolar.com>"

ENV FRESHRSS_VERSION=1.26.3
ARG SHA256=6605d3aa738085743824f7ad6d53812c802de7d0ad3d43226f948d3cb953aeec
ADD https://github.com/FreshRSS/FreshRSS/archive/refs/tags/$FRESHRSS_VERSION.tar.gz /usr/src/freshrss.tar.gz

ENV FRESHRSS_EXTENSIONS_VERSION=ec349ee5a6c77bcc02a4b7b6cb7926887b8e0809
ARG FRESHRSS_EXTENSIONS_SHA256=3462814716feffffb6a456f81fe98a20db948637951e5975919d1023eae8bfcc
ADD https://github.com/FreshRSS/Extensions/archive/$FRESHRSS_EXTENSIONS_VERSION.tar.gz /usr/src/extensions.tar.gz

ENV PHP_MAX_EXECUTION_TIME 300
ENV PHP_MEMORY_LIMIT 32M
ENV DATA_PATH /usr/local/freshrss/data

WORKDIR /usr/local/freshrss

RUN set -ex; \
    apk add --no-cache \
		bash \
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
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
    } > $PHP_INI_DIR/conf.d/freshrss-defaults.ini; \
	echo "$SHA256 */usr/src/freshrss.tar.gz" | sha256sum -c -; \
	echo "$FRESHRSS_EXTENSIONS_SHA256 */usr/src/extensions.tar.gz" | sha256sum -c -; \
    rm -rf \
        /usr/src/php.tar.xz \
        /usr/src/php.tar.xz.asc \
        /var/cache/apk/* \
        /var/tmp/* \
        /tmp/*

COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY resources/exclude.txt /usr/src/freshrss.exclude

VOLUME /usr/local/freshrss/data
VOLUME /usr/local/freshrss/html/p

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
