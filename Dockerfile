# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS frontend
WORKDIR /build
COPY package.json ./
COPY docker/image/package-lock.json ./package-lock.json
RUN npm ci --no-audit --no-fund
COPY . .
RUN cp .env.docker .env && npx vite build -- fromcmd && rm .env

FROM kuaifan/php:swoole-8.4 AS application
ARG REVISION=unknown
LABEL org.opencontainers.image.source="https://github.com/anlongvip/dootask" \
      org.opencontainers.image.revision="${REVISION}"
USER root
RUN apt-get update && apt-get install -y --no-install-recommends rsync \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/dootask
COPY . .
COPY --from=frontend /build/public ./public
# LaravelS and the application's helper autoload currently live in require-dev.
# Keep them until the upstream dependency layout is migrated.
RUN mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && composer install --prefer-dist --no-interaction --optimize-autoloader \
    && find bin docker/image docker/php docker/crontab -type f -name '*.sh' -exec sed -i 's/\r$//' {} + \
    && sed -i 's/\r$//' bin/auto \
    && chmod +x bin/auto docker/image/start.sh \
    && printf '%s\n' "$REVISION" > IMAGE_REVISION
COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/image/low-memory.ini /usr/local/etc/php/conf.d/zz-dootask.ini
COPY docker/php/php.conf docker/php/license.conf docker/crontab/crontab.conf /etc/supervisor/conf.d/
WORKDIR /var/www
ENTRYPOINT ["/opt/dootask/docker/image/start.sh"]
