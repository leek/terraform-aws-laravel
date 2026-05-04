# ========================================
# Configuration Variables
# ========================================
# Update these for different projects/environments
# OR create a Makefile.config file to override (see Makefile.config.example)

# Project configuration
APP_NAME := laravel
AWS_PROFILE :=
AWS_REGION := us-east-1

# Paths
TF_DIR := terraform
DOCKER_FILE := docker/Dockerfile
SSH_KEY := ~/.ssh/$(APP_NAME)-bastion-key.pem

# Docker configuration
DOCKER_PLATFORM := linux/amd64

# ECS services to deploy
ECS_SERVICES := service queue-worker scheduler

# Environments
ENVIRONMENTS := staging uat production

# Environment-specific emojis
EMOJI_staging := 🚧
EMOJI_uat := 🧪
EMOJI_production := 🏭

# Load optional local config (overrides above variables)
-include Makefile.config

# ========================================
# Helper Functions
# ========================================

# Get environment emoji
emoji = $(EMOJI_$(1))

# AWS CLI with profile (disable pager to avoid interactive less)
aws = AWS_PAGER="" aws --profile $(AWS_PROFILE)

# Terraform with AWS profile, region, and directory
tf = AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) terraform -chdir=$(TF_DIR)

# Get cluster name for environment
cluster = $(APP_NAME)-$(1)

# Get service name for environment and service type
service = $(APP_NAME)-$(1)-$(2)

# ========================================
# Terraform Targets
# ========================================

.PHONY: terraform.init
terraform.init:
	@echo "⚙️  Initializing Terraform..."
	@$(tf) init -input=false

.PHONY: terraform.inframap
terraform.inframap:
	@echo "🗺️  Generating infrastructure map..."
	@$(tf) state pull | inframap generate | dot -Tpng -o inframap.png

# Generic terraform plan target
.PHONY: terraform.%.plan
terraform.%.plan:
	@echo "🔍 Running Terraform plan for $(call emoji,$*) $* environment..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $*
	@$(tf) plan -var-file="environments/$*.tfvars"

# Generic terraform apply target
.PHONY: terraform.%.apply
terraform.%.apply:
	@echo "🚀 Applying Terraform changes for $(call emoji,$*) $* environment..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $*
	@$(tf) apply -auto-approve -var-file="environments/$*.tfvars"

# Production requires explicit confirmation (no auto-approve)
.PHONY: terraform.production.apply
terraform.production.apply:
	@echo "🚀 Applying Terraform changes for $(call emoji,production) production environment..."
	@$(tf) workspace select production 2>/dev/null || $(tf) workspace new production
	@$(tf) apply -var-file="environments/production.tfvars"

# ========================================
# Docker Targets
# ========================================

# Docker build arguments (override via Makefile.config or CLI)
APP_SERVER_MODE := php-fpm
INSTALL_PGSQL := true
INSTALL_CHROMIUM := false
INSTALL_GNUPG := false
COMPOSER_IMAGE := composer:2
CMD ?= php artisan about
MIGRATE_CMD ?= php artisan migrate --force --isolated

# Image tag defaults to the current git SHA so deploys are deterministic and
# previous task-definition revisions remain meaningful rollback points.
GIT_SHA := $(shell git rev-parse HEAD 2>/dev/null)
IMAGE_TAG ?= $(GIT_SHA)

# Generic docker build target
.PHONY: docker.%.build
docker.%.build:
	@if [ -z "$(IMAGE_TAG)" ]; then \
		echo "❌ ERROR: IMAGE_TAG is empty (not a git checkout?). Pass IMAGE_TAG=<tag>"; \
		exit 1; \
	fi
	@echo "🛠️  Building Docker image for $(call emoji,$*) $* ($(DOCKER_PLATFORM)) tag=$(IMAGE_TAG)..."
	@docker buildx build --platform $(DOCKER_PLATFORM) -f $(DOCKER_FILE) \
		--build-arg APP_SERVER_MODE=$(APP_SERVER_MODE) \
		--build-arg INSTALL_PGSQL=$(INSTALL_PGSQL) \
		--build-arg INSTALL_CHROMIUM=$(INSTALL_CHROMIUM) \
		--build-arg INSTALL_GNUPG=$(INSTALL_GNUPG) \
		--build-arg COMPOSER_IMAGE=$(COMPOSER_IMAGE) \
		-t $(APP_NAME)-$*:$(IMAGE_TAG) \
		-t $(APP_NAME)-$*:latest --load .
	@echo "✅ Docker image built and tagged as $(APP_NAME)-$*:$(IMAGE_TAG)"

# Generic docker push target with ECS deployment pinned to IMAGE_TAG
.PHONY: docker.%.push
docker.%.push: aws.login
	@if [ -z "$(IMAGE_TAG)" ]; then \
		echo "❌ ERROR: IMAGE_TAG is empty"; exit 1; \
	fi
	@ECR=$$($(tf) output -raw ecr_repository_url) && \
	if [ -z "$$ECR" ]; then \
		echo "❌ ERROR: terraform output 'ecr_repository_url' is empty"; \
		exit 1; \
	fi && \
	echo "📦 Tagging $(APP_NAME)-$*:$(IMAGE_TAG) -> $$ECR:$(IMAGE_TAG)" && \
	docker tag $(APP_NAME)-$*:$(IMAGE_TAG) $$ECR:$(IMAGE_TAG) && \
	echo "🚀 Pushing $$ECR:$(IMAGE_TAG)" && \
	docker push $$ECR:$(IMAGE_TAG) && \
	$(MAKE) aws.$*.deploy.quiet IMAGE_TAG=$(IMAGE_TAG) && \
	echo "🎉 Push completed successfully!"

NIGHTWATCH_AGENT_UPSTREAM := laravelphp/nightwatch-agent
NIGHTWATCH_AGENT_TAG := v1

.PHONY: ecr.%.mirror-nightwatch
ecr.%.mirror-nightwatch:
	@echo "🪞 Mirroring $(NIGHTWATCH_AGENT_UPSTREAM):$(NIGHTWATCH_AGENT_TAG) -> ECR ($*)..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true
	@ECR=$$($(tf) output -raw nightwatch_agent_repository_url 2>/dev/null) && \
	if [ -z "$$ECR" ]; then \
		echo "❌ ERROR: terraform output 'nightwatch_agent_repository_url' is empty. Set enable_nightwatch_agent_mirror = true and apply first."; \
		exit 1; \
	fi && \
	REGISTRY=$$(echo "$$ECR" | cut -d'/' -f1) && \
	echo "🔐 Logging in to $$REGISTRY" && \
	$(aws) ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin "$$REGISTRY" && \
	echo "⬇️  Pulling $(NIGHTWATCH_AGENT_UPSTREAM):$(NIGHTWATCH_AGENT_TAG) ($(DOCKER_PLATFORM))" && \
	docker pull --platform $(DOCKER_PLATFORM) $(NIGHTWATCH_AGENT_UPSTREAM):$(NIGHTWATCH_AGENT_TAG) && \
	echo "🏷️  Tagging as $$ECR:$(NIGHTWATCH_AGENT_TAG)" && \
	docker tag $(NIGHTWATCH_AGENT_UPSTREAM):$(NIGHTWATCH_AGENT_TAG) $$ECR:$(NIGHTWATCH_AGENT_TAG) && \
	echo "⬆️  Pushing $$ECR:$(NIGHTWATCH_AGENT_TAG)" && \
	docker push $$ECR:$(NIGHTWATCH_AGENT_TAG) && \
	echo "✅ Mirror complete. Set nightwatch_agent_image = \"$$ECR:$(NIGHTWATCH_AGENT_TAG)\" in environments/$*.tfvars, then apply."

# ========================================
# AWS Targets
# ========================================

.PHONY: aws.credentials
aws.credentials:
	@echo "Exporting AWS credentials for profile '$(AWS_PROFILE)'..."
	@aws --profile $(AWS_PROFILE) configure export-credentials --format env
	@echo ""
	@echo "Run: eval \$$(make aws.credentials 2>/dev/null | grep ^export)"

.PHONY: aws.login
aws.login:
	@$(aws) ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin \
	$$($(tf) output -raw ecr_repository_url | cut -d'/' -f1)

# Generic ECS redeploy target (with output)
.PHONY: aws.%.redeploy
aws.%.redeploy:
	@echo "🔄 Force redeploying $* services..."
	@$(foreach svc,$(ECS_SERVICES), \
		$(aws) ecs update-service \
			--cluster $(call cluster,$*) \
			--service $(call service,$*,$(svc)) \
			--force-new-deployment \
			--query "service.deployments[0].status" \
			--output text && \
	) true
	@echo "⏳ Waiting for all deployments to stabilize..."
	@$(aws) ecs wait services-stable \
		--cluster $(call cluster,$*) \
		--services $(foreach svc,$(ECS_SERVICES),$(call service,$*,$(svc)))
	@echo "✅ $* redeployment completed!"

# Silent redeploy (for use in docker.push)
.PHONY: aws.%.redeploy.quiet
aws.%.redeploy.quiet:
	@$(foreach svc,$(ECS_SERVICES), \
		echo "🔄 Triggering ECS deployment for $(svc)" && \
		$(aws) ecs update-service \
			--cluster $(call cluster,$*) \
			--service $(call service,$*,$(svc)) \
			--force-new-deployment \
			--query "service.deployments[0].status" \
			--output text && \
	) true

# Register a new task-definition revision pinned to $(IMAGE_TAG) for every
# service in $(ECS_SERVICES) and point each service at it. Image rewrite is
# scoped to containers from this app's ECR repo so sidecars keep their own refs.
.PHONY: aws.%.deploy.quiet
aws.%.deploy.quiet:
	@set -eu; \
	if [ -z "$(IMAGE_TAG)" ]; then \
		echo "❌ ERROR: IMAGE_TAG is empty"; exit 1; \
	fi; \
	if ! command -v jq >/dev/null 2>&1; then \
		echo "❌ ERROR: jq is required"; exit 1; \
	fi; \
	ECR=$$($(tf) output -raw ecr_repository_url); \
	if [ -z "$$ECR" ]; then \
		echo "❌ ERROR: terraform output 'ecr_repository_url' is empty"; \
		exit 1; \
	fi; \
	CLUSTER=$(call cluster,$*); \
	NEW_IMAGE="$$ECR:$(IMAGE_TAG)"; \
	echo "📌 Pinning task definitions to $$NEW_IMAGE"; \
	for svc in $(ECS_SERVICES); do \
		SERVICE_NAME="$(call service,$*,$$svc)"; \
		echo "==> $$SERVICE_NAME"; \
		CURRENT_TD_ARN=$$($(aws) ecs describe-services \
			--cluster "$$CLUSTER" \
			--services "$$SERVICE_NAME" \
			--query 'services[0].taskDefinition' \
			--output text); \
		TD_FAMILY=$$(echo "$$CURRENT_TD_ARN" | awk -F'[:/]' '{print $$(NF-1)}'); \
		TD_JSON=$$($(aws) ecs describe-task-definition \
			--task-definition "$$TD_FAMILY" \
			--query 'taskDefinition' \
			--output json); \
		NEW_TD_JSON=$$(echo "$$TD_JSON" | jq \
			--arg repo "$$ECR" \
			--arg new_image "$$NEW_IMAGE" \
			'.containerDefinitions |= map(if (.image | startswith($$repo + ":")) then .image = $$new_image else . end) | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)'); \
		NEW_TD_ARN=$$($(aws) ecs register-task-definition \
			--cli-input-json "$$NEW_TD_JSON" \
			--query 'taskDefinition.taskDefinitionArn' \
			--output text); \
		echo "   registered $$NEW_TD_ARN"; \
		$(aws) ecs update-service \
			--cluster "$$CLUSTER" \
			--service "$$SERVICE_NAME" \
			--task-definition "$$NEW_TD_ARN" \
			--query 'service.serviceArn' \
			--output text; \
	done

# Generic ECS SSH target
.PHONY: aws.%.ssh
aws.%.ssh:
	@echo "🔗 Connecting to $* container..."
	@TASK_ID=$$($(aws) ecs list-tasks \
		--cluster $(call cluster,$*) \
		--service $(call service,$*,service) \
		--desired-status RUNNING \
		--query "taskArns[0]" \
		--output text | cut -d'/' -f3) && \
	if [ -z "$$TASK_ID" ] || [ "$$TASK_ID" = "None" ]; then \
		echo "❌ ERROR: No running tasks found for $(call service,$*,service)"; \
		exit 1; \
	fi && \
	echo "📋 Connecting to task: $$TASK_ID" && \
	( trap 'kill 0' INT TERM; \
	  $(aws) ecs execute-command \
	    --cluster $(call cluster,$*) \
	    --task $$TASK_ID \
	    --container app \
	    --interactive \
	    --command "/bin/sh -l" \
	)

.PHONY: aws.%.artisan
aws.%.artisan:
	@echo "🚀 Running one-off task on $(call emoji,$*) $*..."
	@SVC_JSON=$$($(aws) ecs describe-services \
		--cluster $(call cluster,$*) \
		--services $(call service,$*,service) \
		--output json) && \
	TD_ARN=$$(echo "$$SVC_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['services'][0]['taskDefinition'])") && \
	SUBNETS=$$(echo "$$SVC_JSON" | python3 -c "import sys,json; c=json.load(sys.stdin)['services'][0]['networkConfiguration']['awsvpcConfiguration']; print(','.join(c['subnets']))") && \
	SGS=$$(echo "$$SVC_JSON" | python3 -c "import sys,json; c=json.load(sys.stdin)['services'][0]['networkConfiguration']['awsvpcConfiguration']; print(','.join(c['securityGroups']))") && \
	CONTAINER=$$($(aws) ecs describe-task-definition \
		--task-definition "$$TD_ARN" \
		--query "taskDefinition.containerDefinitions[0].name" \
		--output text) && \
	echo "📋 Task definition: $$TD_ARN" && \
	echo "📦 Container: $$CONTAINER" && \
	echo "🔧 Command: $(CMD)" && \
	RUN_ARN=$$($(aws) ecs run-task \
		--cluster $(call cluster,$*) \
		--task-definition "$$TD_ARN" \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$$SUBNETS],securityGroups=[$$SGS],assignPublicIp=DISABLED}" \
		--overrides '{"containerOverrides":[{"name":"'"$$CONTAINER"'","command":["sh","-lc","$(CMD)"]}]}' \
		--query "tasks[0].taskArn" \
		--output text) && \
	if [ -z "$$RUN_ARN" ] || [ "$$RUN_ARN" = "None" ]; then \
		echo "❌ Failed to start task"; \
		exit 1; \
	fi && \
	echo "🆔 Task: $$RUN_ARN" && \
	echo "⏳ Waiting for task to complete..." && \
	$(aws) ecs wait tasks-stopped --cluster $(call cluster,$*) --tasks "$$RUN_ARN" && \
	EXIT_CODE=$$($(aws) ecs describe-tasks \
		--cluster $(call cluster,$*) \
		--tasks "$$RUN_ARN" \
		--query "tasks[0].containers[?name==\`$$CONTAINER\`].exitCode | [0]" \
		--output text) && \
	echo "Exit code: $$EXIT_CODE" && \
	if [ "$$EXIT_CODE" != "0" ]; then \
		echo "❌ Command failed"; \
		$(aws) ecs describe-tasks \
			--cluster $(call cluster,$*) \
			--tasks "$$RUN_ARN" \
			--query "tasks[0].stoppedReason" \
			--output text; \
		exit 1; \
	fi && \
	echo "✅ Command completed successfully"

# ========================================
# Bastion Targets
# ========================================

.PHONY: bastion.%.tunnel.db bastion.%.tunnel.mysql bastion.%.tunnel.pgsql
bastion.%.tunnel.db:
	@echo "🔗 Opening database tunnel to $* via bastion..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true && \
	BASTION_IP=$$($(tf) output -raw bastion_public_ip 2>/dev/null) && \
	RDS_ENDPOINT=$$($(tf) output -raw rds_endpoint 2>/dev/null) && \
	RDS_PORT=$$($(tf) output -raw rds_port 2>/dev/null) && \
	if [ -z "$$BASTION_IP" ] || echo "$$BASTION_IP" | grep -q "Bastion disabled"; then \
		echo "❌ ERROR: Bastion host not enabled in $*"; \
		exit 1; \
	fi && \
	echo "📋 Tunneling localhost:$$RDS_PORT -> $$RDS_ENDPOINT:$$RDS_PORT via $$BASTION_IP" && \
	ssh -i $(SSH_KEY) -N -L $$RDS_PORT:$$RDS_ENDPOINT:$$RDS_PORT ec2-user@$$BASTION_IP

bastion.%.tunnel.mysql:
	@$(MAKE) bastion.$*.tunnel.db

bastion.%.tunnel.pgsql:
	@$(MAKE) bastion.$*.tunnel.db

.PHONY: bastion.%.tunnel.redis
bastion.%.tunnel.redis:
	@echo "🔗 Opening Redis tunnel to $* via bastion..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true && \
	BASTION_IP=$$($(tf) output -raw bastion_public_ip 2>/dev/null) && \
	REDIS_ENDPOINT=$$($(tf) output -raw redis_endpoint 2>/dev/null) && \
	REDIS_PORT=$$($(tf) output -raw redis_port 2>/dev/null) && \
	if [ -z "$$BASTION_IP" ] || echo "$$BASTION_IP" | grep -q "Bastion disabled"; then \
		echo "❌ ERROR: Bastion host not enabled in $*"; \
		exit 1; \
	fi && \
	echo "📋 Tunneling localhost:$$REDIS_PORT -> $$REDIS_ENDPOINT:$$REDIS_PORT via $$BASTION_IP" && \
	ssh -i $(SSH_KEY) -N -L $$REDIS_PORT:$$REDIS_ENDPOINT:$$REDIS_PORT ec2-user@$$BASTION_IP

# Generic bastion SSH target
.PHONY: bastion.%.ssh
bastion.%.ssh:
	@echo "🔗 Connecting to $* bastion host..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* && \
	BASTION_IP=$$($(tf) output -raw bastion_public_ip 2>/dev/null) && \
	if [ -z "$$BASTION_IP" ] || [ "$$BASTION_IP" = "null" ] || echo "$$BASTION_IP" | grep -q "Bastion disabled"; then \
		echo "❌ ERROR: Bastion host not found or not enabled in $*"; \
		echo "💡 TIP: Set enable_bastion = true in $(TF_DIR)/environments/$*.tfvars"; \
		exit 1; \
	fi && \
	echo "📋 Connecting to bastion at $$BASTION_IP" && \
	ssh -i $(SSH_KEY) ec2-user@$$BASTION_IP

# ========================================
# Deploy Targets
# ========================================

.PHONY: deploy.%
deploy.%:
	@$(MAKE) docker.$*.build IMAGE_TAG=$(IMAGE_TAG)
	@$(MAKE) docker.$*.push IMAGE_TAG=$(IMAGE_TAG)
	@echo "🚚 Running post-deploy migrations..."
	@$(MAKE) aws.$*.artisan CMD="$(MIGRATE_CMD)"
	@echo "🎉 Deploy to $* complete!"

# ========================================
# S3 Targets
# ========================================

.PHONY: s3.%.seed
s3.%.seed:
	@$(tf) workspace select $* && \
	BUCKET=$$($(tf) output -raw app_filesystem_bucket_name) && \
	echo "📦 Seeding S3 bucket $$BUCKET for $*..." && \
	$(aws) s3 sync storage/app/public/ s3://$$BUCKET/public/ --sse aws:kms \
		--exclude ".*" && \
	echo "✅ S3 seed complete!"

# ========================================
# Git Deployment Targets
# ========================================

# Generic git deploy target
.PHONY: git.%.deploy
git.%.deploy:
	@echo "🚀 Deploying latest code to $(call emoji,$*) $*..."
	@(git branch -D $* || true) && \
	git checkout -b $* && \
	git push -f origin $* && \
	git checkout main

# ========================================
# Convenience Targets
# ========================================

.PHONY: help
help:
	@echo "$(APP_NAME) Makefile Commands"
	@echo "=============================="
	@echo ""
	@echo "Terraform:"
	@echo "  make terraform.init                    - Initialize Terraform"
	@echo "  make terraform.<env>.plan              - Plan infrastructure changes"
	@echo "  make terraform.<env>.apply             - Apply infrastructure changes"
	@echo ""
	@echo "Docker:"
	@echo "  make docker.<env>.build                - Build Docker image"
	@echo "  make docker.<env>.push                 - Push image and deploy pinned task definitions"
	@echo "  make ecr.<env>.mirror-nightwatch       - Mirror Nightwatch agent image into ECR"
	@echo ""
	@echo "Deploy:"
	@echo "  make deploy.<env>                      - Build, push, and run migrations"
	@echo ""
	@echo "AWS/ECS:"
	@echo "  make aws.credentials                   - Export AWS profile credentials"
	@echo "  make aws.login                         - Login to ECR"
	@echo "  make aws.<env>.redeploy                - Force redeploy all ECS services"
	@echo "  make aws.<env>.ssh                     - SSH into ECS container"
	@echo "  make aws.<env>.artisan CMD=\"...\"        - Run one-off command on ECS"
	@echo ""
	@echo "Bastion:"
	@echo "  make bastion.<env>.ssh                 - SSH into bastion host"
	@echo "  make bastion.<env>.tunnel.db           - Database tunnel via bastion"
	@echo "  make bastion.<env>.tunnel.redis        - Redis tunnel via bastion"
	@echo ""
	@echo "S3:"
	@echo "  make s3.<env>.seed                     - Seed S3 bucket with storage/app/public"
	@echo ""
	@echo "Git:"
	@echo "  make git.<env>.deploy                  - Deploy via git branch"
	@echo ""
	@echo "Environments: $(ENVIRONMENTS)"

.DEFAULT_GOAL := help
