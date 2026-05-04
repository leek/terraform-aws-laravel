# ========================================
# ECS Cluster
# ========================================

#checkov:skip=CKV_TF_1:Version constraint provides better balance between reproducibility and maintainability
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 6.0"

  cluster_name = "${var.app_name}-${var.environment}"

  create_cloudwatch_log_group = false

  cluster_setting = var.enable_container_insights ? [
    { name = "containerInsights", value = "enhanced" }
  ] : []

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = var.log_group_name
      }
    }
  }

  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 50
    }
    FARGATE_SPOT = {
      weight = 50
    }
  }

  tags = var.common_tags
}