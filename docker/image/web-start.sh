#!/bin/sh
set -eu
mkdir -p /etc/nginx/templates
# Docker can give the recreated PHP container a new IP. Resolve its service name
# periodically, so updating just the application container does not leave a 502.
sed '/upstream service {/a\
    zone service 64k;\
    resolver 127.0.0.11 valid=10s ipv6=off;
s/server php:20000 /server php:20000 resolve /' \
    /var/www/docker/nginx/default.conf > /etc/nginx/templates/default.conf.template
exec /docker-entrypoint.sh nginx -g 'daemon off;'
