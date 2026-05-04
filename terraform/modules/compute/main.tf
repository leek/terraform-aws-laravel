# ========================================
# Compute Module
# ========================================
#
# This module has been split into multiple files for better organization:
# - locals.tf: Shared configuration and environment variables
# - cluster.tf: ECS cluster configuration
# - task-definitions.tf: ECS task definitions for web and worker services
# - services.tf: ECS service configurations
# - autoscaling.tf: Auto scaling policies and scheduled actions