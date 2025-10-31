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
        echo "Starting web server..."
        SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-web.conf"
        ;;
    queue-worker)
        echo "Starting queue worker..."
        SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-queue-worker.conf"
        ;;
    scheduler)
        echo "Starting scheduler..."
        SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-scheduler.conf"
        ;;
    nightwatch)
        echo "Starting Nightwatch monitoring dashboard..."
        SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord-nightwatch.conf"
        ;;
    *)
        echo "❌ ERROR: Unknown CONTAINER_ROLE: $CONTAINER_ROLE"
        echo "Valid values: web, queue-worker, scheduler, nightwatch"
        exit 1
        ;;
esac

# Start supervisord with the appropriate configuration
exec /usr/bin/supervisord -c "$SUPERVISOR_CONF"
