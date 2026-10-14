#!/usr/bin/env bash
set -euo pipefail
export DOOTASK_IMAGE=dootask-candidate:ci
export DB_PASSWORD="$(openssl rand -hex 24)"
export DB_ROOT_PASSWORD="$(openssl rand -hex 24)"
export APP_PORT=12229
export APP_URL=http://localhost:12229
export DOOTASK_PROJECT="ci-image-$(openssl rand -hex 6)"
export VOLUME_PREFIX="$DOOTASK_PROJECT"
compose=(docker compose -f docker/image/compose.yml)
# Every run uses unique project and volume names, isolated from any installation.
cleanup() {
    status=$?
    if (( status != 0 )); then
        "${compose[@]}" logs --no-color --tail=100
    fi
    "${compose[@]}" down --volumes
    exit "$status"
}
trap cleanup EXIT
"${compose[@]}" up -d --wait --wait-timeout 600
curl -fsS "$APP_URL/health" >/dev/null
echo 'Fresh install: all services healthy'
version="$(jq -r .version package.json)"
curl -fsS "$APP_URL/api/system/setting" | jq -e --arg version "$version" '.ret == 1 and .data.server_version == $version' >/dev/null
"${compose[@]}" exec -T php sh -c 'printf image-update-sentinel > public/uploads/image-update-sentinel.txt; sha256sum .env storage/app/install-credentials.txt > storage/app/image-update-checksums; printf outdated > IMAGE_REVISION'
"${compose[@]}" exec -T mariadb sh -c 'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "INSERT INTO pre_settings (name, \`desc\`, setting, created_at, updated_at) VALUES ('\''ci_image_sentinel'\'', '\''image update'\'', '\''preserved'\'', NOW(), NOW())"'
"${compose[@]}" up -d --force-recreate --wait --wait-timeout 600
"${compose[@]}" exec -T php sha256sum -c storage/app/image-update-checksums
"${compose[@]}" exec -T php sh -c 'cmp /var/www/IMAGE_REVISION /opt/dootask/IMAGE_REVISION'
test "$(curl -fsS "$APP_URL/uploads/image-update-sentinel.txt")" = image-update-sentinel
"${compose[@]}" exec -T mariadb sh -c 'mariadb --skip-column-names -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SELECT setting FROM pre_settings WHERE name='\''ci_image_sentinel'\''"' | grep -qx preserved
curl -fsS "$APP_URL/health" >/dev/null
"${compose[@]}" up -d --no-deps --force-recreate --wait --wait-timeout 180 php
curl --retry 15 --retry-delay 2 --retry-all-errors -fsS "$APP_URL/health" >/dev/null
echo 'Container update: code replaced; database, files, configuration and credentials preserved'
