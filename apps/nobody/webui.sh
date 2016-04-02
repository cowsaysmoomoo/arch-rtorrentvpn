#!/bin/bash

# wait for rtorrent process to start (listen for port)
while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
	sleep 0.1
done

echo "[info] rtorrent started, setting up webui..."

# if php timezone specified then set in php.ini (prevents issues with dst and rutorrent schedulder plugin)
if [[ ! -z "${PHP_TZ}" ]]; then

	echo "[info] Setting PHP timezone to ${PHP_TZ}..."
	sed -i -e "s~.*date\.timezone \= .*~date\.timezone \= ${PHP_TZ}~g" "/etc/php/php.ini"

else

	echo "[warn] PHP timezone not set, this may cause issues with the ruTorrent Scheduler plugin, see here for a list of available PHP timezones, http://php.net/manual/en/timezones.php"

fi

# if nginx cert files dont exist then copy defaults to host config volume (location specified in nginx.conf, no need to soft link)
if [[ ! -f "/config/nginx/certs/host.cert" || ! -f "/config/nginx/certs/host.key" ]]; then

	echo "[info] nginx cert files doesnt exist, copying default to /config/nginx/certs/..."

	mkdir -p /config/nginx/certs
	cp /home/nobody/nginx/certs/* /config/nginx/certs/

else

	echo "[info] nginx cert files already exists, skipping copy"

fi

# if nginx security file doesnt exist then copy default to host config volume (location specified in nginx.conf, no need to soft link)
if [ ! -f "/config/nginx/security/auth" ]; then

	echo "[info] nginx security file doesnt exist, copying default to /config/nginx/security/..."

	mkdir -p /config/nginx/security
	cp /home/nobody/nginx/security/* /config/nginx/security/

else

	echo "[info] nginx security file already exists, skipping copy"

fi

# if nginx config file doesnt exist then copy default to host config volume (soft linked)
if [ ! -f "/config/nginx/config/nginx.conf" ]; then

	echo "[info] nginx config file doesnt exist, copying default to /config/nginx/config/..."

	mkdir -p /config/nginx/config

	# if nginx defaiult config file exists then delete
	if [[ -f "/etc/nginx/nginx.conf" && ! -L "/etc/nginx/nginx.conf" ]]; then
		rm -rf /etc/nginx/nginx.conf
	fi
	
	cp /home/nobody/nginx/config/* /config/nginx/config/

else

	echo "[info] nginx config file already exists, skipping copy"

fi

# create soft link to nginx config file
ln -fs /config/nginx/config/nginx.conf /etc/nginx/nginx.conf

# if share folder exists in container then rename
if [[ -d "/usr/share/webapps/rutorrent/share" && ! -L "/usr/share/webapps/rutorrent/share" ]]; then
	mv /usr/share/webapps/rutorrent/share /usr/share/webapps/rutorrent/share-backup 2>/dev/null || true
fi

# if rutorrent share folder doesnt exist then copy default to host config volume (soft linked)
if [ ! -d "/config/rutorrent/share" ]; then

	echo "[info] rutorrent share folder doesnt exist, copying default to /config/rutorrent/share/..."

	mkdir -p /config/rutorrent/share
	if [[ -d "/usr/share/webapps/rutorrent/share-backup" && ! -L "/usr/share/webapps/rutorrent/share-backup" ]]; then
		cp -R /usr/share/webapps/rutorrent/share-backup/* /config/rutorrent/share/ 2>/dev/null || true
	fi

else

	echo "[info] rutorrent share folder already exists, skipping copy"

fi

# create soft link to rutorrent share folder
ln -fs /config/rutorrent/share /usr/share/webapps/rutorrent

# if plugins folder exists in container then rename
if [ -d "/usr/share/webapps/rutorrent/plugins" ]; then
	mv /usr/share/webapps/rutorrent/plugins /usr/share/webapps/rutorrent/plugins-backup 2>/dev/null || true
fi

# if rutorrent plugins folder dont exist then rsync defaults to host config volume (rsync copy, cannot soft link)
if [ ! -d "/config/rutorrent/plugins" ]; then

	echo "[info] rutorrent plugins folder doesnt exist, copying default to /config/rutorrent/plugins/..."

	mkdir -p /config/rutorrent/plugins
	rsync -a --delete /usr/share/webapps/rutorrent/plugins-backup/* /config/rutorrent/plugins/ 2>/dev/null || true

else

	echo "[info] rutorrent plugins folder already exists, skipping copy"

fi

# rsync config plugins to rutorrent plugins folder
rsync -a --delete /config/rutorrent/plugins /usr/share/webapps/rutorrent

echo "[info] starting php-fpm..."

# run php-fpm and specify path to pid file
if [ ! -f "/run/php-fpm/php-fpm.sock" ]; then
	echo "[info] php-fpm not running, creating socket..."
	/usr/bin/php-fpm --pid /home/nobody/php-fpm.pid
fi

echo "[info] php-fpm started, starting nginx..."

# run nginx in foreground and specify path to pid file
/usr/bin/nginx -g "daemon off; pid /home/nobody/nginx.pid;"