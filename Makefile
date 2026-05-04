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

# Database sync (used by db.%.tunnel, db.%.push, db.%.pull)
# Override these in Makefile.config for non-default Postgres setups.
DB_SYNC_PORT := 54320
DB_SYNC_REMOTE_PORT := 5432
DB_SYNC_EXCLUDE_TABLES := cache cache_locks jobs job_batches failed_jobs
DB_SYNC_POSTGRES_BIN := /opt/homebrew/opt/postgresql@16/bin
DB_SYNC_PG_DUMP := $(DB_SYNC_POSTGRES_BIN)/pg_dump

# When true, db.%.push publishes the local APP_KEY to /<APP_NAME>/<env>/APP_PREVIOUS_KEYS
# so encrypted columns from the local snapshot remain decryptable on the remote.
# Requires application support for APP_PREVIOUS_KEYS-style key rotation.
DB_SYNC_PUBLISH_APP_PREVIOUS_KEYS := false

# Load optional local config (overrides above variables)
-include Makefile.config

# ========================================
# Helper Functions
# ========================================

# Get environment emoji
emoji = $(EMOJI_$(1))

# AWS CLI with profile (disable pager to avoid interactive less)
aws = AWS_PAGER="" aws --profile $(AWS_PROFILE)

# Read a value from local .env file (e.g. $(call dotenv,DB_PASSWORD))
dotenv = $(shell grep -E '^$(1)=' .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")

# Build pg_dump --exclude-table-data flags from DB_SYNC_EXCLUDE_TABLES
db_exclude_tables = $(foreach tbl,$(DB_SYNC_EXCLUDE_TABLES),--exclude-table-data=$(tbl))

# Terraform with AWS profile, region, and directory.
# Set USE_AWS_CREDS_EXPORT=true in Makefile.config to export credentials via the
# CLI before invoking terraform — useful with SSO / role-chained profiles where
# the Go SDK's profile resolution differs from the CLI's.
ifeq ($(USE_AWS_CREDS_EXPORT),true)
aws_creds = eval $$(aws --profile $(AWS_PROFILE) configure export-credentials --format env) &&
else
aws_creds =
endif
tf = $(aws_creds) AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) terraform -chdir=$(TF_DIR)

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
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true
	@$(tf) plan -var-file="environments/$*.tfvars"

# Generic terraform apply target
.PHONY: terraform.%.apply
terraform.%.apply:
	@echo "🚀 Applying Terraform changes for $(call emoji,$*) $* environment..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true
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
INSTALL_MYSQL := true
INSTALL_PGSQL := true
INSTALL_CHROMIUM := false
INSTALL_GNUPG := false
INSTALL_IMAGICK := false
COMPOSER_IMAGE := composer:2.9.7@sha256:dc292c5c0f95f526b051d4c341bf08e7e2b18504c74625e3203d7f123050e318
CMD ?= php artisan about
# Migrations bracketed by down/up to keep destructive migrations off live traffic.
# Override in Makefile.config if your release flow handles this elsewhere.
MIGRATE_CMD ?= php artisan down && php artisan migrate --force --isolated && php artisan up

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
		--build-arg INSTALL_MYSQL=$(INSTALL_MYSQL) \
		--build-arg INSTALL_PGSQL=$(INSTALL_PGSQL) \
		--build-arg INSTALL_CHROMIUM=$(INSTALL_CHROMIUM) \
		--build-arg INSTALL_GNUPG=$(INSTALL_GNUPG) \
		--build-arg INSTALL_IMAGICK=$(INSTALL_IMAGICK) \
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
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true 2>/dev/null || true
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
	@set -euo pipefail; \
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

# Start bastion instance (cost saver: stop bastions off-hours, start when needed)
.PHONY: bastion.%.start
bastion.%.start:
	@echo "🚀 Starting $* bastion host..."
	@INSTANCE_ID=$$($(aws) ec2 describe-instances \
		--filters "Name=tag:Name,Values=$(APP_NAME)-$*-bastion" "Name=instance-state-name,Values=stopped" \
		--query 'Reservations[].Instances[].InstanceId' --output text) && \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "⚠️  No stopped bastion found for $* (may already be running)"; \
		exit 0; \
	fi && \
	$(aws) ec2 start-instances --instance-ids $$INSTANCE_ID > /dev/null && \
	echo "⏳ Waiting for instance to be running..." && \
	$(aws) ec2 wait instance-running --instance-ids $$INSTANCE_ID && \
	echo "⏳ Waiting for status checks..." && \
	$(aws) ec2 wait instance-status-ok --instance-ids $$INSTANCE_ID && \
	NEW_IP=$$($(aws) ec2 describe-instances --instance-ids $$INSTANCE_ID \
		--query 'Reservations[].Instances[].PublicIpAddress' --output text) && \
	echo "✅ Bastion running at $$NEW_IP"

# Stop bastion instance
.PHONY: bastion.%.stop
bastion.%.stop:
	@echo "🛑 Stopping $* bastion host..."
	@INSTANCE_ID=$$($(aws) ec2 describe-instances \
		--filters "Name=tag:Name,Values=$(APP_NAME)-$*-bastion" "Name=instance-state-name,Values=running" \
		--query 'Reservations[].Instances[].InstanceId' --output text) && \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "⚠️  No running bastion found for $* (may already be stopped)"; \
		exit 0; \
	fi && \
	$(aws) ec2 stop-instances --instance-ids $$INSTANCE_ID > /dev/null && \
	echo "✅ Bastion stopping (instance: $$INSTANCE_ID)"

.PHONY: bastion.%.tunnel.db bastion.%.tunnel.mysql bastion.%.tunnel.pgsql
bastion.%.tunnel.db:
	@echo "🔗 Opening database tunnel to $* via bastion..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true 2>/dev/null || true && \
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
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true 2>/dev/null || true && \
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
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true && \
	BASTION_IP=$$($(tf) output -raw bastion_public_ip 2>/dev/null) && \
	if [ -z "$$BASTION_IP" ] || [ "$$BASTION_IP" = "null" ] || echo "$$BASTION_IP" | grep -q "Bastion disabled"; then \
		echo "❌ ERROR: Bastion host not found or not enabled in $*"; \
		echo "💡 TIP: Set enable_bastion = true in $(TF_DIR)/environments/$*.tfvars"; \
		exit 1; \
	fi && \
	echo "📋 Connecting to bastion at $$BASTION_IP" && \
	ssh -i $(SSH_KEY) ec2-user@$$BASTION_IP

# ========================================
# Database Sync Targets (PostgreSQL)
# ========================================
#
# These targets shell out via the bastion host. PostgreSQL-only — adapt
# accordingly for MySQL/MariaDB engines.
#
# Required setup:
#   - var.enable_bastion = true with an SSH key on disk at $(SSH_KEY)
#   - pg_dump on the local machine at $(DB_SYNC_PG_DUMP)
#   - jq on PATH

# PostgreSQL tunnel on a non-conflicting port (DB_SYNC_PORT, default 54320)
# so it can run alongside a local Postgres on 5432.
.PHONY: db.%.tunnel
db.%.tunnel:
	@echo "🔗 Opening database tunnel to $* on port $(DB_SYNC_PORT)..."
	@$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true && \
	BASTION_IP=$$($(tf) output -raw bastion_public_ip 2>/dev/null) && \
	RDS_ENDPOINT=$$($(tf) output -raw rds_endpoint 2>/dev/null) && \
	if [ -z "$$BASTION_IP" ] || echo "$$BASTION_IP" | grep -q "Bastion disabled"; then \
		echo "❌ ERROR: Bastion host not enabled in $*"; \
		exit 1; \
	fi && \
	echo "📋 Tunneling localhost:$(DB_SYNC_PORT) -> $$RDS_ENDPOINT:$(DB_SYNC_REMOTE_PORT) via $$BASTION_IP" && \
	ssh -i $(SSH_KEY) -N -L $(DB_SYNC_PORT):$$RDS_ENDPOINT:$(DB_SYNC_REMOTE_PORT) ec2-user@$$BASTION_IP

# Push local Postgres database to remote (DESTRUCTIVE — overwrites remote).
# Requires interactive confirmation. Brackets in maintenance mode + EXIT trap.
.PHONY: db.%.push
db.%.push:
	@set -o pipefail && \
	if ! command -v jq >/dev/null 2>&1; then \
		echo "❌ ERROR: jq is required. Install with: brew install jq"; \
		exit 1; \
	fi && \
	if [ ! -x "$(DB_SYNC_PG_DUMP)" ]; then \
		echo "❌ ERROR: pg_dump is required at $(DB_SYNC_PG_DUMP). Set DB_SYNC_PG_DUMP in Makefile.config to override."; \
		exit 1; \
	fi && \
	echo "⚠️  WARNING: You are about to OVERWRITE the $* remote database with your LOCAL data." && \
	printf "Type 'yes-push-$*' to confirm: " && \
	read CONFIRM && \
	if [ "$$CONFIRM" != "yes-push-$*" ]; then \
		echo "❌ Aborted."; \
		exit 1; \
	fi && \
	echo "⬆️  Pushing local database to $*..." && \
	$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true && \
	BASTION_IP=$$($(tf) output -raw bastion_public_ip 2>/dev/null) && \
	RDS_ENDPOINT=$$($(tf) output -raw rds_endpoint 2>/dev/null) && \
	RDS_DB_NAME=$$($(tf) output -raw rds_database_name 2>/dev/null) && \
	RDS_SECRET_ARN=$$($(tf) output -raw rds_secret_arn 2>/dev/null) && \
	if [ -z "$$BASTION_IP" ] || echo "$$BASTION_IP" | grep -q "Bastion disabled"; then \
		echo "❌ ERROR: Bastion host not enabled in $*"; \
		exit 1; \
	fi && \
	echo "🔑 Retrieving RDS credentials..." && \
	SECRET_JSON=$$($(aws) secretsmanager get-secret-value \
		--secret-id "$$RDS_SECRET_ARN" \
		--query 'SecretString' \
		--output text 2>/dev/null) && \
	if [ -z "$$SECRET_JSON" ]; then \
		echo "❌ ERROR: Failed to retrieve RDS secret"; \
		exit 1; \
	fi && \
	RDS_USER=$$(echo "$$SECRET_JSON" | jq -r '.username') && \
	RDS_PASS=$$(echo "$$SECRET_JSON" | jq -r '.password') && \
	if [ -z "$$RDS_USER" ] || [ "$$RDS_USER" = "null" ]; then \
		echo "❌ ERROR: Failed to parse credentials from secret"; \
		exit 1; \
	fi && \
	APP_DB_USER=$$($(aws) ssm get-parameter \
		--name "/$(APP_NAME)/$*/DB_USERNAME" \
		--with-decryption \
		--query 'Parameter.Value' \
		--output text 2>/dev/null) && \
	if [ -z "$$APP_DB_USER" ] || [ "$$APP_DB_USER" = "None" ]; then \
		echo "❌ ERROR: Failed to retrieve app database user from SSM"; \
		exit 1; \
	fi && \
	echo "🔐 Ensuring restore can switch to $$APP_DB_USER..." && \
	printf '%s\n' 'GRANT :"app_user" TO :"admin_user";' | \
	ssh -i $(SSH_KEY) -o ConnectTimeout=10 ec2-user@$$BASTION_IP \
		"PGPASSWORD='$$RDS_PASS' psql -h $$RDS_ENDPOINT -U '$$RDS_USER' -d '$$RDS_DB_NAME' -v ON_ERROR_STOP=1 -v admin_user='$$RDS_USER' -v app_user='$$APP_DB_USER'" && \
	MAINTENANCE_ENABLED=0 && \
	trap 'if [ "$$MAINTENANCE_ENABLED" = "1" ]; then echo "🔧 Bringing $* back online after failure..."; $(MAKE) aws.$*.artisan CMD="php artisan up"; fi' EXIT && \
	echo "🔧 Putting $* in maintenance mode..." && \
	$(MAKE) aws.$*.artisan CMD="php artisan down" && \
	MAINTENANCE_ENABLED=1 && \
	echo "📦 Dumping local database $(call dotenv,DB_DATABASE) and importing into $$RDS_DB_NAME via bastion..." && \
	{ \
		printf '%s\n' \
			'BEGIN;' \
			'DROP SCHEMA IF EXISTS public CASCADE;' \
			'CREATE SCHEMA public AUTHORIZATION :"app_user";' \
			'GRANT ALL ON SCHEMA public TO public;' \
			'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;' \
			'CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;' \
			'CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;' \
			'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;' \
			'SET ROLE :"app_user";'; \
		PGPASSWORD=$(call dotenv,DB_PASSWORD) "$(DB_SYNC_PG_DUMP)" -h $(call dotenv,DB_HOST) -p $(call dotenv,DB_PORT) \
			-U $(call dotenv,DB_USERNAME) \
			--no-owner --no-privileges --no-comments \
			$(call db_exclude_tables) \
			$(call dotenv,DB_DATABASE) && \
		printf '%s\n' 'RESET ROLE;' 'COMMIT;'; \
	} | \
	ssh -i $(SSH_KEY) -o ConnectTimeout=10 ec2-user@$$BASTION_IP \
		"PGPASSWORD='$$RDS_PASS' psql -h $$RDS_ENDPOINT -U '$$RDS_USER' -d '$$RDS_DB_NAME' -v ON_ERROR_STOP=1 -v app_user='$$APP_DB_USER'" && \
	if [ "$(DB_SYNC_PUBLISH_APP_PREVIOUS_KEYS)" = "true" ]; then \
		echo "🔐 Publishing local APP_KEY as APP_PREVIOUS_KEYS on $* so encrypted columns remain decryptable..."; \
		LOCAL_APP_KEY="$(call dotenv,APP_KEY)"; \
		if [ -z "$$LOCAL_APP_KEY" ]; then \
			echo "❌ ERROR: Local APP_KEY not found in .env — cannot publish APP_PREVIOUS_KEYS"; \
			exit 1; \
		fi; \
		$(aws) ssm put-parameter \
			--name "/$(APP_NAME)/$*/APP_PREVIOUS_KEYS" \
			--value "$$LOCAL_APP_KEY" \
			--type SecureString \
			--overwrite >/dev/null; \
		echo "🔄 Force redeploying $* services to pick up APP_PREVIOUS_KEYS..."; \
		$(MAKE) aws.$*.redeploy; \
	fi && \
	echo "🔧 Bringing $* back online..." && \
	$(MAKE) aws.$*.artisan CMD="php artisan up" && \
	MAINTENANCE_ENABLED=0 && \
	trap - EXIT && \
	echo "✅ Push to $* complete!" && \
	if [ "$(DB_SYNC_PUBLISH_APP_PREVIOUS_KEYS)" = "true" ]; then \
		echo "ℹ️  Run 'make db.$*.push.clear-previous-keys' after you've re-encrypted or no longer need the old key."; \
	fi

# Reset APP_PREVIOUS_KEYS on remote to a sentinel and redeploy.
.PHONY: db.%.push.clear-previous-keys
db.%.push.clear-previous-keys:
	@echo "🧹 Clearing APP_PREVIOUS_KEYS on $*..."
	@$(aws) ssm put-parameter \
		--name "/$(APP_NAME)/$*/APP_PREVIOUS_KEYS" \
		--value "0" \
		--type SecureString \
		--overwrite >/dev/null
	@$(MAKE) aws.$*.redeploy
	@echo "✅ APP_PREVIOUS_KEYS cleared on $*"

# Pull remote Postgres database to local (DESTRUCTIVE — overwrites local).
# Production requires interactive confirmation.
.PHONY: db.%.pull
db.%.pull:
	@command -v jq >/dev/null 2>&1 || { echo "❌ ERROR: jq is required. Install with: brew install jq"; exit 1; } && \
	if [ "$*" = "production" ]; then \
		echo "⚠️  WARNING: You are about to OVERWRITE your local database with PRODUCTION data."; \
		printf "Type 'yes-pull-production' to confirm: "; \
		read CONFIRM; \
		if [ "$$CONFIRM" != "yes-pull-production" ]; then \
			echo "❌ Aborted."; \
			exit 1; \
		fi; \
	fi && \
	echo "⬇️  Pulling $* database to local..." && \
	$(tf) workspace select $* 2>/dev/null || $(tf) workspace new $* 2>/dev/null || true && \
	BASTION_IP=$$($(tf) output -raw bastion_public_ip 2>/dev/null) && \
	RDS_ENDPOINT=$$($(tf) output -raw rds_endpoint 2>/dev/null) && \
	RDS_DB_NAME=$$($(tf) output -raw rds_database_name 2>/dev/null) && \
	RDS_SECRET_ARN=$$($(tf) output -raw rds_secret_arn 2>/dev/null) && \
	if [ -z "$$BASTION_IP" ] || echo "$$BASTION_IP" | grep -q "Bastion disabled"; then \
		echo "❌ ERROR: Bastion host not enabled in $*"; \
		exit 1; \
	fi && \
	echo "🔑 Retrieving RDS credentials..." && \
	SECRET_JSON=$$($(aws) secretsmanager get-secret-value \
		--secret-id "$$RDS_SECRET_ARN" \
		--query 'SecretString' \
		--output text 2>/dev/null) && \
	if [ -z "$$SECRET_JSON" ]; then \
		echo "❌ ERROR: Failed to retrieve RDS secret"; \
		exit 1; \
	fi && \
	RDS_USER=$$(echo "$$SECRET_JSON" | jq -r '.username') && \
	RDS_PASS=$$(echo "$$SECRET_JSON" | jq -r '.password') && \
	if [ -z "$$RDS_USER" ] || [ "$$RDS_USER" = "null" ]; then \
		echo "❌ ERROR: Failed to parse credentials from secret"; \
		exit 1; \
	fi && \
	echo "📥 Dumping remote database $$RDS_DB_NAME via bastion and importing locally..." && \
	ssh -i $(SSH_KEY) -o ConnectTimeout=10 ec2-user@$$BASTION_IP \
		"PGPASSWORD='$$RDS_PASS' pg_dump -h $$RDS_ENDPOINT -U '$$RDS_USER' \
		--no-owner --no-privileges --clean --if-exists \
		'$$RDS_DB_NAME'" | \
	PGPASSWORD=$(call dotenv,DB_PASSWORD) psql -h $(call dotenv,DB_HOST) -p $(call dotenv,DB_PORT) \
		-U $(call dotenv,DB_USERNAME) \
		-d $(call dotenv,DB_DATABASE) -v ON_ERROR_STOP=1 && \
	echo "✅ Pull from $* complete!"

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
	@echo "  make bastion.<env>.start               - Start (boot) the bastion EC2 instance"
	@echo "  make bastion.<env>.stop                - Stop the bastion EC2 instance"
	@echo "  make bastion.<env>.tunnel.db           - Database tunnel via bastion"
	@echo "  make bastion.<env>.tunnel.redis        - Redis tunnel via bastion"
	@echo ""
	@echo "Database (Postgres-only):"
	@echo "  make db.<env>.tunnel                   - Tunnel to RDS on DB_SYNC_PORT (54320)"
	@echo "  make db.<env>.push                     - Overwrite remote DB with local (interactive confirmation)"
	@echo "  make db.<env>.pull                     - Overwrite local DB with remote"
	@echo ""
	@echo "S3:"
	@echo "  make s3.<env>.seed                     - Seed S3 bucket with storage/app/public"
	@echo ""
	@echo "Git:"
	@echo "  make git.<env>.deploy                  - Deploy via git branch"
	@echo ""
	@echo "Environments: $(ENVIRONMENTS)"

.DEFAULT_GOAL := help
