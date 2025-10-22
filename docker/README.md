# Docker Container Roles

This Docker image supports multiple container roles via the `CONTAINER_ROLE` environment variable:

- **web** (default): Runs nginx + php-fpm to serve the web application
- **queue-worker**: Runs Laravel queue workers to process SQS jobs
- **scheduler**: Runs Laravel scheduler to dispatch scheduled tasks

## Architecture

The ECS deployment consists of three separate services:

1. **Web Service** (`apollo-{env}-service`): Multiple tasks behind ALB for handling HTTP requests
2. **Queue Worker Service** (`apollo-{env}-queue-worker`): Dedicated tasks for processing queue jobs
3. **Scheduler Service** (`apollo-{env}-scheduler`): Single task for running scheduled commands

This separation ensures:
- Queue workers don't compete with each other (no duplicate job processing)
- Only one scheduler runs at a time (no duplicate scheduled tasks)
- Web servers can scale independently of workers

# Test Locally

```bash
# Build the container
docker build -f docker/Dockerfile -t apollo-local .

# Run web server locally
docker run -p 8080:80 \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=web \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  apollo-local

# Run queue worker locally
docker run \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=queue-worker \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  apollo-local

# Run scheduler locally
docker run \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=scheduler \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  apollo-local

# Test in browser
open http://localhost:8080
```

## Debug

```bash
# Check container logs
docker logs <container-id>

# Get into the container to debug
docker run -it apollo-local /bin/sh

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
docker build --platform linux/amd64 -f docker/Dockerfile -t apollo-staging .

# Tag and push to ECR
docker tag apollo-staging:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Force ECS to deploy new image (all services)
aws ecs update-service --cluster apollo-staging --service apollo-staging-service --force-new-deployment
aws ecs update-service --cluster apollo-staging --service apollo-staging-queue-worker --force-new-deployment
aws ecs update-service --cluster apollo-staging --service apollo-staging-scheduler --force-new-deployment
```
