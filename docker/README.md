# Docker Container Roles

This Docker image supports multiple container roles via the `CONTAINER_ROLE` environment variable:

- **web** (default): Runs nginx + php-fpm (or Laravel Octane) to serve the web application
- **queue-worker**: Runs Laravel queue workers to process SQS jobs
- **scheduler**: Runs Laravel scheduler to dispatch scheduled tasks

## Application Server Mode

The **web** container role supports two modes via the `APP_SERVER_MODE` environment variable:

- **php-fpm** (default): Traditional PHP-FPM with Nginx as FastCGI proxy
  - Most compatible with all Laravel applications
  - Battle-tested and stable
  - Good for applications with moderate traffic

- **octane**: Laravel Octane with Swoole and Nginx as reverse proxy
  - 2-5x better performance and throughput
  - Lower latency and memory usage
  - Requires Laravel 8+ with Octane package installed
  - Application must be Octane-compatible (no global state)

## Architecture

The ECS deployment consists of three separate services:

1. **Web Service** (`{app_name}-{env}-service`): Multiple tasks behind ALB for handling HTTP requests
2. **Queue Worker Service** (`{app_name}-{env}-queue-worker`): Dedicated tasks for processing queue jobs
3. **Scheduler Service** (`{app_name}-{env}-scheduler`): Single task for running scheduled commands

This separation ensures:
- Queue workers don't compete with each other (no duplicate job processing)
- Only one scheduler runs at a time (no duplicate scheduled tasks)
- Web servers can scale independently of workers

# Test Locally

```bash
# Build the container
docker build -f docker/Dockerfile -t laravel-local .

# Run web server locally with PHP-FPM (default)
docker run -p 8080:80 \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=web \
  -e APP_SERVER_MODE=php-fpm \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  laravel-local

# Run web server locally with Laravel Octane
docker run -p 8080:80 \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=web \
  -e APP_SERVER_MODE=octane \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  laravel-local

# Run queue worker locally
docker run \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=queue-worker \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  laravel-local

# Run scheduler locally
docker run \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=scheduler \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  laravel-local

# Test in browser
open http://localhost:8080
```

## Debug

```bash
# Check container logs
docker logs <container-id>

# Get into the container to debug
docker run -it laravel-local /bin/sh

# Check nginx logs (web containers only)
docker exec <container-id> tail -f /var/log/nginx/error.log

# Check supervisor logs
docker exec <container-id> tail -f /var/log/supervisor/supervisord.log
```

# Push to AWS (staging)

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d'/' -f1)

# Build specifically for x86_64 (AMD64) platform
docker build --platform linux/amd64 -f docker/Dockerfile -t laravel-staging .

# Tag and push to ECR
docker tag laravel-staging:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Force ECS to deploy new image (all services)
aws ecs update-service --cluster laravel-staging --service laravel-staging-service --force-new-deployment
aws ecs update-service --cluster laravel-staging --service laravel-staging-queue-worker --force-new-deployment
aws ecs update-service --cluster laravel-staging --service laravel-staging-scheduler --force-new-deployment
```
