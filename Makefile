aws.login:
	aws ecr get-login-password --region us-east-1 | \
	docker login --username AWS --password-stdin \
	$(shell terraform -chdir=terraform output -raw ecr_repository_url | cut -d'/' -f1)

terraform.init:
	@echo "⚙️  Initializing Terraform..."
	terraform -chdir=terraform init -input=false

terraform.staging.plan:
	@echo "🔍 Running Terraform plan for 🚧 staging environment..."
	terraform -chdir=terraform workspace select staging 2>/dev/null || terraform -chdir=terraform workspace new staging
	terraform -chdir=terraform plan -var-file="environments/staging.tfvars"

terraform.staging.apply:
	@echo "🚀 Applying Terraform changes for 🚧 staging environment..."
	terraform -chdir=terraform workspace select staging 2>/dev/null || terraform -chdir=terraform workspace new staging
	terraform -chdir=terraform apply -auto-approve -var-file="environments/staging.tfvars"

terraform.production.plan:
	@echo "🔍 Running Terraform plan for 🚧 production environment..."
	terraform -chdir=terraform workspace select production 2>/dev/null || terraform -chdir=terraform workspace new production
	terraform -chdir=terraform plan -var-file="environments/production.tfvars"

terraform.production.apply:
	@echo "🚀 Applying Terraform changes for 🚧 production environment..."
	terraform -chdir=terraform workspace select production 2>/dev/null || terraform -chdir=terraform workspace new production
	terraform -chdir=terraform apply -var-file="environments/production.tfvars"

docker.staging.build:
	@echo "🛠️  Building Docker image for 🚧 staging (linux/amd64)..."
	@docker build --platform linux/amd64 -f docker/Dockerfile -t laravel-staging .
	@echo "✅ Docker image built and tagged as laravel-staging:latest"

docker.staging.push:
	@ECR=$$(terraform -chdir=terraform output -raw ecr_repository_url) && \
	if [ -z "$$ECR" ]; then \
		echo "❌ ERROR: terraform output 'ecr_repository_url' is empty"; \
		exit 1; \
	fi && \
	echo "📦 Tagging image as $$ECR:latest" && \
	docker tag laravel-staging:latest $$ECR:latest && \
	echo "🚀 Pushing image to $$ECR:latest" && \
	docker push $$ECR:latest && \
	echo "🔄 Triggering ECS deployment" && \
	aws ecs update-service \
		--cluster laravel-staging \
		--service laravel-staging-service \
		--force-new-deployment \
		--query "service.deployments[0].status" \
  		--output text && \
	echo "🎉 Push triggered successfully!"

aws.staging.redeploy:
	@echo "🔄 Force redeploying staging service..."
	@aws ecs update-service \
		--cluster laravel-staging \
		--service laravel-staging-service \
		--force-new-deployment \
		--query "service.deployments[0].status" \
		--output text && \
	echo "⏳ Waiting for deployment to stabilize..." && \
	aws ecs wait services-stable \
		--cluster laravel-staging \
		--services laravel-staging-service && \
	echo "✅ Staging redeployment completed!"

aws.staging.ssh:
	@echo "🔗 Connecting to staging container..."
	@TASK_ID=$$(aws ecs list-tasks --cluster laravel-staging --service laravel-staging-service --desired-status RUNNING --query "taskArns[0]" --output text | cut -d'/' -f3) && \
	if [ -z "$$TASK_ID" ] || [ "$$TASK_ID" = "None" ]; then \
		echo "❌ ERROR: No running tasks found for laravel-staging service"; \
		exit 1; \
	fi && \
	echo "📋 Connecting to task: $$TASK_ID" && \
	( trap 'kill 0' INT TERM; \
	  aws ecs execute-command \
	    --cluster laravel-staging \
	    --task $$TASK_ID \
	    --container app \
	    --interactive \
	    --command "/bin/sh -l" \
	)

aws.production.ssh:
	@echo "🔗 Connecting to production container..."
	@TASK_ID=$$(aws ecs list-tasks --cluster laravel-production --service laravel-production-service --desired-status RUNNING --query "taskArns[0]" --output text | cut -d'/' -f3) && \
	if [ -z "$$TASK_ID" ] || [ "$$TASK_ID" = "None" ]; then \
		echo "❌ ERROR: No running tasks found for laravel-production service"; \
		exit 1; \
	fi && \
	echo "📋 Connecting to task: $$TASK_ID" && \
	( trap 'kill 0' INT TERM; \
		aws ecs execute-command \
			--cluster laravel-production \
			--task $$TASK_ID \
			--container app \
			--interactive \
			--command "/bin/sh -l" \
	)
