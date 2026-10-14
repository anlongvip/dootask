#!/usr/bin/env bash
set -euo pipefail
umask 022

# /var/www is the persistent source volume shared with Nginx and appstore.
# Image upgrades replace code while retaining configuration and user data.
mkdir -p /var/www
exec 9>/var/www/.image-install.lock
flock 9
rsync -a --delete \
    --exclude='.env' --exclude='.image-*' \
    --exclude='/storage/' --exclude='/public/uploads/' --exclude='/public/summary/' \
    --exclude='/config/LICENSE' --exclude='/config/license' \
    --exclude='/docker/appstore/' --exclude='/docker/logs/' \
    /opt/dootask/ /var/www/
cd /var/www
cp docker/image/compose.yml docker-compose.yml
mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs \
    storage/app public/uploads public/summary docker/appstore/{apps,config,log,temp,ai-kb} /var/log/supervisor
php /opt/dootask/docker/image/initialize.php
php artisan migrate --force
if [[ ! -f .image-initialized ]]; then
    php artisan db:seed --force
    php /opt/dootask/docker/image/initialize.php credentials
    touch .image-initialized
fi
printf '* * * * * /bin/sh /var/www/docker/crontab/crontab.sh\n' | crontab -
flock -u 9
exec 9>&-
exec /entrypoint.sh "$@"
