# syntax=docker/dockerfile:1.4

# ========================================
# Stage 1: Base image with PHP extensions
# ========================================
FROM php:8.4-fpm-alpine AS base

# Update Alpine packages to get security patches including libxml2
RUN apk update && apk upgrade --no-cache

# Install system dependencies required for extensions
RUN apk add --no-cache \
    # For gd
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    # For zip
    libzip-dev \
    # For pgsql
    postgresql-dev \
    # For intl
    icu-dev \
    oniguruma-dev \
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
    openssl \
    # Runtime deps for the final image
    nginx \
    supervisor \
    mysql-client \
    openssh-client \
    nano

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    gd \
    mbstring \
    intl \
    opcache \
    bcmath \
    zip \
    pcntl \
    sockets \
    # PECL
    && pecl install redis \
    && docker-php-ext-enable redis \
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
# Stage 2: Build application dependencies
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
    autoconf \
    automake \
    libtool \
    build-base

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy dependency files
COPY composer.json composer.lock auth.json* package.json package-lock.json ./

# Copy the rest of the application files
COPY . .

# Install PHP and Node dependencies with cache mounts
RUN --mount=type=cache,target=/root/.composer/cache \
    composer install --no-scripts --optimize-autoloader --no-interaction --prefer-dist && \
    composer clear-cache

RUN --mount=type=cache,target=/root/.npm \
    npm ci && \
    npm cache clean --force && \
    npm run build

# Create minimal .env for build-time caching (will be replaced at runtime)
# We need APP_KEY and basic config for artisan commands to work
RUN cp .env.example .env && \
    php artisan key:generate --no-interaction --force

# Cache Laravel artifacts at build time (except config which depends on env vars)
# This significantly speeds up container startup time
RUN php artisan event:cache --no-interaction && \
    php artisan route:cache --no-interaction && \
    php artisan view:cache --no-interaction && \
    php artisan icons:cache --no-interaction && \
    php artisan filament:cache-components --no-interaction

# ========================================
# Stage 3: Final application image
# ========================================
FROM base AS app

# Set working directory
WORKDIR /var/www/html

# Copy built application from the builder stage
COPY --from=builder --chown=www-data:www-data /var/www/html .

# Copy configuration files
COPY docker/.profile /root/.profile
COPY --chown=www-data:www-data docker/nginx/ /etc/nginx
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/php/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/supervisord-web.conf /etc/supervisor/conf.d/supervisord-web.conf
COPY docker/supervisord-queue-worker.conf /etc/supervisor/conf.d/supervisord-queue-worker.conf
COPY docker/supervisord-scheduler.conf /etc/supervisor/conf.d/supervisord-scheduler.conf
COPY docker/entrypoint.sh /entrypoint.sh

# Make entrypoint executable and create supervisor log directory
RUN chmod +x /entrypoint.sh \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /etc/nginx/custom.d \
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
