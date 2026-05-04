# syntax=docker/dockerfile:1.4

# ========================================
# Build Arguments
# ========================================
ARG COMPOSER_IMAGE=composer:2
ARG APP_SERVER_MODE=php-fpm
ARG INSTALL_MYSQL=true
ARG INSTALL_PGSQL=true
ARG INSTALL_CHROMIUM=false
ARG INSTALL_GNUPG=false

# ========================================
# Stage: Composer binary
# ========================================
FROM ${COMPOSER_IMAGE} AS composer_bin

# ========================================
# Stage: Download Octane binaries
# ========================================
FROM alpine:latest AS binaries

ARG APP_SERVER_MODE
ARG RR_VERSION=v2025.1.4
ARG FP_VERSION=v1.9.1

RUN apk add --no-cache curl

# Download RoadRunner binary for Laravel Octane (only when needed)
RUN set -o pipefail && \
    if [ "$APP_SERVER_MODE" = "octane-roadrunner" ]; then \
      ARCH="$(uname -m)" && \
      case "$ARCH" in \
        x86_64) RR_ARCH="amd64" ;; \
        aarch64|arm64) RR_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
      esac && \
      mkdir -p /tmp/rr && \
      curl -sSL https://github.com/roadrunner-server/roadrunner/releases/download/${RR_VERSION}/roadrunner-${RR_VERSION#v}-linux-${RR_ARCH}.tar.gz \
        | tar -xz -C /tmp/rr && \
      find /tmp/rr -type f \( -name 'rr' -o -name 'roadrunner' \) | head -1 | xargs -I {} mv {} /usr/local/bin/roadrunner && \
      chmod +x /usr/local/bin/roadrunner && \
      rm -rf /tmp/rr; \
    else \
      touch /usr/local/bin/roadrunner; \
    fi

# Download FrankenPHP binary for Laravel Octane (only when needed)
RUN set -o pipefail && \
    if [ "$APP_SERVER_MODE" = "octane-frankenphp" ]; then \
      ARCH="$(uname -m)" && \
      case "$ARCH" in \
        x86_64) FP_ARCH="x86_64" ;; \
        aarch64|arm64) FP_ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
      esac && \
      curl -sSL https://github.com/dunglas/frankenphp/releases/download/${FP_VERSION}/frankenphp-linux-${FP_ARCH} \
        -o /usr/local/bin/frankenphp && \
      chmod +x /usr/local/bin/frankenphp; \
    else \
      touch /usr/local/bin/frankenphp; \
    fi

# ========================================
# Stage: Base image with PHP extensions
# ========================================
FROM php:8.4-fpm-alpine AS base

ARG APP_SERVER_MODE
ARG INSTALL_MYSQL
ARG INSTALL_PGSQL
ARG INSTALL_CHROMIUM
ARG INSTALL_GNUPG

# Install system dependencies (merged apk update + upgrade + add into one layer)
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache \
    # For gd
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    # For zip
    libzip-dev \
    # For intl
    icu-dev \
    oniguruma-dev \
    # For soap
    libxml2-dev \
    # For uv
    libuv-dev \
    linux-headers \
    # General build tools needed for pecl and source installs
    build-base \
    autoconf \
    automake \
    libtool \
    nasm \
    git \
    # Runtime deps for the final image
    nginx \
    supervisor \
    openssh-client \
    nano && \
    if [ "$INSTALL_MYSQL" = "true" ]; then apk add --no-cache mysql-client; fi && \
    if [ "$INSTALL_PGSQL" = "true" ]; then apk add --no-cache postgresql-dev postgresql-client; fi && \
    if [ "$INSTALL_CHROMIUM" = "true" ]; then apk add --no-cache chromium nss harfbuzz ttf-freefont font-noto-emoji; fi && \
    if [ "$INSTALL_GNUPG" = "true" ]; then apk add --no-cache gnupg; fi

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo \
    gd \
    mbstring \
    intl \
    opcache \
    bcmath \
    zip \
    pcntl \
    sockets \
    soap \
    # Database drivers are optional so projects can ship lean single-engine images
    && if [ "$INSTALL_MYSQL" = "true" ]; then docker-php-ext-install pdo_mysql; fi \
    && if [ "$INSTALL_PGSQL" = "true" ]; then docker-php-ext-install pdo_pgsql; fi \
    # PECL - redis is always installed
    && pecl install redis \
    && docker-php-ext-enable redis \
    # APCu backs Composer's APCu autoloader cache
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    # Swoole - only when using octane-swoole
    && if [ "$APP_SERVER_MODE" = "octane-swoole" ]; then \
        pecl install swoole && docker-php-ext-enable swoole; \
    fi \
    # Cleanup after PHP extensions are built
    && apk del build-base autoconf automake libtool nasm git \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Install uv extension from source (for Laravel Reverb performance)
# RUN git clone https://github.com/bwoebi/php-uv.git /tmp/php-uv \
#     && cd /tmp/php-uv \
#     && phpize \
#     && ./configure \
#     && make \
#     && make install \
#     && docker-php-ext-enable uv \
#     && rm -rf /tmp/php-uv

# ========================================
# Stage: Build application dependencies
# ========================================
FROM base AS builder

# Set working directory
WORKDIR /var/www/html

# Install additional build-time dependencies
RUN apk add --no-cache \
    curl \
    unzip \
    zip \
    python3 \
    nodejs \
    npm \
    build-base \
    autoconf \
    automake \
    libtool

# Install Composer
COPY --from=composer_bin /usr/bin/composer /usr/bin/composer

# Copy dependency files
COPY composer.json composer.lock auth.json* package.json package-lock.json .npmrc* ./

# Copy optional vendor-src, vendor-npm, and patches directories if they exist
RUN --mount=type=bind,source=.,target=/src \
    if [ -d /src/vendor-src ]; then cp -a /src/vendor-src ./vendor-src; fi && \
    if [ -d /src/vendor-npm ]; then cp -a /src/vendor-npm ./vendor-npm; fi && \
    if [ -d /src/patches ]; then cp -a /src/patches ./patches; fi

# Install PHP dependencies with cache mounts
# Note: We do not run `composer clear-cache` here because the cache is mounted and automatically managed by BuildKit.
RUN --mount=type=cache,target=/root/.composer/cache \
    composer install --no-scripts --optimize-autoloader --no-interaction --prefer-dist --no-dev

# Install NPM dependencies with cache mounts
RUN --mount=type=cache,target=/root/.npm \
    npm ci --include=optional

# Copy the rest of the application files
COPY . .

# Regenerate the optimized autoloader after app/ source is present.
RUN composer dump-autoload --optimize --classmap-authoritative --apcu --no-scripts --no-interaction

# Create minimal .env for build-time caching (will be replaced at runtime)
# We need APP_KEY and basic config for artisan commands to work
# Override CACHE_STORE to avoid database connections during build
RUN cp .env.example .env && \
    (CACHE_STORE=array php artisan key:generate --no-interaction --force --no-ansi || true)

# Build frontend assets
RUN npm run build

# Cache Laravel artifacts at build time (except config which depends on env vars)
# This significantly speeds up container startup time
# Override CACHE_STORE to avoid database connections during build
# Set memory_limit for resource-intensive caching operations
RUN CACHE_STORE=array php -d memory_limit=-1 artisan filament:assets --no-interaction --no-ansi && \
    CACHE_STORE=array php -d memory_limit=-1 artisan event:cache --no-interaction --no-ansi && \
    CACHE_STORE=array php -d memory_limit=-1 artisan view:cache --no-interaction --no-ansi && \
    CACHE_STORE=array php -d memory_limit=-1 artisan icons:cache --no-interaction --no-ansi && \
    CACHE_STORE=array php -d memory_limit=-1 artisan filament:cache-components --no-interaction --no-ansi

# ========================================
# Stage: Final application image
# ========================================
FROM base AS app

# Set working directory
WORKDIR /var/www/html

# Copy built application from the builder stage
COPY --from=builder --chown=www-data:www-data /var/www/html .

# Copy Octane binaries from binaries stage (empty placeholders when not needed)
COPY --from=binaries /usr/local/bin/roadrunner /usr/local/bin/roadrunner
COPY --from=binaries /usr/local/bin/frankenphp /usr/local/bin/frankenphp

# Copy configuration files
COPY docker/.profile /root/.profile
COPY --chown=www-data:www-data docker/nginx/ /etc/nginx
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/php/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY docker/supervisord-web.conf /etc/supervisor/conf.d/supervisord-web.conf
COPY docker/supervisord-web-octane-swoole.conf /etc/supervisor/conf.d/supervisord-web-octane-swoole.conf
COPY docker/supervisord-web-octane-roadrunner.conf /etc/supervisor/conf.d/supervisord-web-octane-roadrunner.conf
COPY docker/supervisord-web-octane-frankenphp.conf /etc/supervisor/conf.d/supervisord-web-octane-frankenphp.conf
COPY docker/supervisord-queue-worker.conf /etc/supervisor/conf.d/supervisord-queue-worker.conf
COPY docker/supervisord-scheduler.conf /etc/supervisor/conf.d/supervisord-scheduler.conf
COPY docker/entrypoint.sh /entrypoint.sh

# Make entrypoint executable and create supervisor log directory
RUN chmod +x /entrypoint.sh \
    && mkdir -p /var/log/supervisor /etc/nginx/custom.d \
    && mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache /etc/nginx \
    && chmod -R 775 storage bootstrap/cache \
    && mkdir -p /var/lib/nginx/tmp/client_body \
    /var/lib/nginx/tmp/proxy \
    /var/lib/nginx/tmp/fastcgi \
    /var/lib/nginx/tmp/uwsgi \
    /var/lib/nginx/tmp/scgi \
    && chown -R www-data:www-data /var/lib/nginx/tmp \
    && chmod -R 700 /var/lib/nginx/tmp \
    && chgrp www-data /var/lib/nginx \
    && chmod 750 /var/lib/nginx

# Expose port
EXPOSE 80

# Start with entrypoint script
CMD ["/entrypoint.sh"]
