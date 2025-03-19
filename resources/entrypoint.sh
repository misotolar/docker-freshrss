#!/bin/bash

set -ex

if [ ! -d /usr/src/freshrss ]; then
	mkdir -p /usr/src/freshrss && tar -xf /usr/src/freshrss.tar.gz -C /usr/src/freshrss --exclude-from=/usr/src/freshrss.exclude --strip-components=1
	rsync -rlD --delete --exclude-from /usr/src/freshrss.exclude /usr/src/freshrss/ /usr/local/freshrss/html

	cp -rf /usr/src/freshrss/data /usr/local/freshrss/html/data
	cp -rf /usr/src/freshrss/extensions /usr/local/freshrss/html/extensions

	if [ -n "$FRESHRSS_EXTENSIONS" ]; then
		if [ ! -d /usr/src/extensions ]; then
			mkdir -p /usr/src/extensions && tar -xf /usr/src/extensions.tar.gz -C /usr/src/extensions --strip-components=1 --wildcards --no-anchored "Extensions-${FRESHRSS_EXTENSIONS_VERSION}/xExtension-*"
		fi

		for extension in ${FRESHRSS_EXTENSIONS//,/}; do
			cp -rf "/usr/src/extensions/xExtension-${extension}" "/usr/local/freshrss/html/lib/core-extensions/${extension}"
		done
	fi
fi

cd /usr/local/freshrss/html

./cli/access-permissions.sh
mkdir -p /usr/local/freshrss/data/users/_/
chown -R :www-data /usr/local/freshrss/data
chmod -R g+w /usr/local/freshrss/data

php -f ./cli/prepare.php >/dev/null

if [ -n "$FRESHRSS_INSTALL" ]; then
	php -f ./cli/do-install.php -- \
		$(echo "$FRESHRSS_INSTALL" | sed -r 's/[\r\n]+/\n/g' | paste -s -)
	EXITCODE=$?

	if [ $EXITCODE -eq 3 ]; then
		echo 'FreshRSS already installed; no change performed.'
	elif [ $EXITCODE -eq 0 ]; then
		echo 'FreshRSS successfully installed.'
	else
		echo 'FreshRSS error during installation!'
		exit $EXITCODE
	fi
fi

if [ -n "$FRESHRSS_USER" ]; then
	php -f ./cli/create-user.php -- \
		$(echo "$FRESHRSS_USER" | sed -r 's/[\r\n]+/\n/g' | paste -s -)
	EXITCODE=$?

	if [ $EXITCODE -eq 3 ]; then
		echo 'FreshRSS user already exists; no change performed.'
	elif [ $EXITCODE -eq 0 ]; then
		echo 'FreshRSS user successfully created.'
		./cli/list-users.php | xargs -n1 ./cli/actualize-user.php --user
	else
		echo 'FreshRSS error during the creation of a user!'
		exit $EXITCODE
	fi
fi

./cli/access-permissions.sh
mkdir -p /usr/local/freshrss/data/users/_/
chown -R :www-data /usr/local/freshrss/data
chmod -R g+w /usr/local/freshrss/data

exec "$@"
