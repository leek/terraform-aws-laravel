# Test Locally

```
# Build the container
docker build -f docker/Dockerfile -t laravel-local .

# Run it locally
docker run -p 8080:80 \
  -e APP_ENV=local \
  -e APP_KEY=base64:$(php artisan key:generate --show) \
  laravel-local

# Test in browser
open http://localhost:8080
```

## Debug

```
# Check container logs
docker logs <container-id>

# Get into the container to debug
docker run -it laravel-local /bin/sh

# Check nginx logs
docker exec <container-id> tail -f /var/log/nginx/error.log
```

# Push to AWS (staging)

```
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d'/' -f1)

# Build specifically for x86_64 (AMD64) platform
docker build --platform linux/amd64 -f docker/Dockerfile -t laravel-staging .

# Tag and push to ECR
docker tag laravel-staging:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Force ECS to deploy new image
aws ecs update-service --cluster laravel-staging --service laravel-staging-service --force-new-deployment
```
