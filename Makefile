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

# AWS CLI with profile
aws = aws --profile $(AWS_PROFILE)

# Terraform with AWS profile and directory
tf = AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=$(TF_DIR)

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

# Generic docker build target
.PHONY: docker.%.build
docker.%.build:
	@echo "🛠️  Building Docker image for $(call emoji,$*) $* ($(DOCKER_PLATFORM))..."
	@docker build --platform $(DOCKER_PLATFORM) -f $(DOCKER_FILE) -t $(APP_NAME)-$* .
	@echo "✅ Docker image built and tagged as $(APP_NAME)-$*:latest"

# Generic docker push target with ECS redeployment
.PHONY: docker.%.push
docker.%.push: aws.login
	@ECR=$$($(tf) output -raw ecr_repository_url) && \
	if [ -z "$$ECR" ]; then \
		echo "❌ ERROR: terraform output 'ecr_repository_url' is empty"; \
		exit 1; \
	fi && \
	echo "📦 Tagging image as $$ECR:latest" && \
	docker tag $(APP_NAME)-$*:latest $$ECR:latest && \
	echo "🚀 Pushing image to $$ECR:latest" && \
	docker push $$ECR:latest && \
	$(MAKE) aws.$*.redeploy.quiet && \
	echo "🎉 Push completed successfully!"

# ========================================
# AWS Targets
# ========================================

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

# ========================================
# Bastion Targets
# ========================================

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
	@echo "  make docker.<env>.push                 - Push image and redeploy services"
	@echo ""
	@echo "AWS/ECS:"
	@echo "  make aws.login                         - Login to ECR"
	@echo "  make aws.<env>.redeploy                - Force redeploy all ECS services"
	@echo "  make aws.<env>.ssh                     - SSH into ECS container"
	@echo ""
	@echo "Bastion:"
	@echo "  make bastion.<env>.ssh                 - SSH into bastion host"
	@echo ""
	@echo "Git:"
	@echo "  make git.<env>.deploy                  - Deploy via git branch"
	@echo ""
	@echo "Environments: $(ENVIRONMENTS)"

.DEFAULT_GOAL := help
