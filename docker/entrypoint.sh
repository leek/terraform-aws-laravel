#!/bin/sh
set -e

# ########################################################################### #
# NOTICE:
# This script is used as the entrypoint for the Docker container and
# should do as little as possible to ensure the container starts quickly.
# ########################################################################### #

# Determine which service to run (default to web)
# This can be set via environment variable CONTAINER_ROLE
CONTAINER_ROLE=${CONTAINER_ROLE:-web}

# Determine application server mode (php-fpm or octane)
APP_SERVER_MODE=${APP_SERVER_MODE:-php-fpm}

# Create .env file from .env.example if it doesn't exist
if [ ! -f /var/www/html/.env ]; then
    echo "Creating .env file from .env.example..."
    cp /var/www/html/.env.example /var/www/html/.env
fi

# Setup HTTP Basic Authentication for staging environment (web only)
if [ "$APP_ENV" = "staging" ] && [ "$CONTAINER_ROLE" = "web" ]; then
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

# Cache only config (all other caches are baked into the Docker image at build time)
# Config cache must be done at runtime because it depends on environment variables
echo "Caching Laravel configuration..."
php artisan config:cache --no-interaction || true

# Select the appropriate supervisord config based on container role
case "$CONTAINER_ROLE" in
    web)
        # Select web server config based on APP_SERVER_MODE
        if [ "$APP_SERVER_MODE" = "octane" ]; then
            echo "Starting web server with Laravel Octane..."
            SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-web-octane.conf"
            # Swap nginx config to use Octane reverse proxy
            if [ -f /etc/nginx/custom.d/laravel.conf ]; then
                mv /etc/nginx/custom.d/laravel.conf /etc/nginx/custom.d/.laravel.conf.disabled
            fi
            if [ -f /etc/nginx/custom.d/.laravel-octane.conf ]; then
                mv /etc/nginx/custom.d/.laravel-octane.conf /etc/nginx/custom.d/laravel-octane.conf
            fi
        else
            echo "Starting web server with PHP-FPM..."
            SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-web.conf"
            # Ensure PHP-FPM config is active
            if [ -f /etc/nginx/custom.d/.laravel.conf.disabled ]; then
                mv /etc/nginx/custom.d/.laravel.conf.disabled /etc/nginx/custom.d/laravel.conf
            fi
            if [ -f /etc/nginx/custom.d/laravel-octane.conf ]; then
                mv /etc/nginx/custom.d/laravel-octane.conf /etc/nginx/custom.d/.laravel-octane.conf
            fi
        fi
        ;;
    queue-worker)
        echo "Starting queue worker..."
        SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-queue-worker.conf"
        ;;
    scheduler)
        echo "Starting scheduler..."
        SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-scheduler.conf"
        ;;
    *)
        echo "❌ ERROR: Unknown CONTAINER_ROLE: $CONTAINER_ROLE"
        echo "Valid values: web, queue-worker, scheduler"
        exit 1
        ;;
esac

# Start supervisord with the appropriate configuration
exec /usr/bin/supervisord -c "$SUPERVISOR_CONF"
