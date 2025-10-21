#!/bin/sh
set -e

# ########################################################################### #
# NOTICE:
# This script is used as the entrypoint for the Docker container and
# should do as little as possible to ensure the container starts quickly.
# ########################################################################### #

# Create .env file from .env.example if it doesn't exist
if [ ! -f /var/www/html/.env ]; then
    echo "Creating .env file from .env.example..."
    cp /var/www/html/.env.example /var/www/html/.env
fi

# Setup HTTP Basic Authentication for staging environment
if [ "$APP_ENV" = "staging" ]; then
    echo "Enabling HTTP Basic Authentication for staging environment..."
    if [ -f /etc/nginx/custom.d/.http-auth.conf ]; then
        mv /etc/nginx/custom.d/.http-auth.conf /etc/nginx/custom.d/http-auth.conf
    fi
fi

# Ensure storage directories have proper permissions
echo "Setting storage directory permissions..."
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/testing
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/app/public
mkdir -p /var/www/html/storage/app/private
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

# Optimize Laravel
echo "Optimizing Laravel..."
php artisan optimize --no-interaction || true

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
