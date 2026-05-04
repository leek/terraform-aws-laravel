# ========================================
# ECS Services
# ========================================

resource "aws_ecs_service" "main" {
  name             = "${var.app_name}-${var.environment}-service"
  cluster          = module.ecs.cluster_id
  task_definition  = aws_ecs_task_definition.main.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = 80
  }

  # Deployment configuration to minimize ENI requirements during rolling updates
  # For low desired counts (1-2), allow max 200% to enable proper rolling deploys
  # For higher counts, this still limits to desired_count + 1 extra task
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Give Laravel time to boot before health checks start
  health_check_grace_period_seconds = 120

  # Enable ECS Exec for debugging
  enable_execute_command = true

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-service"
  })
}

# ECS Services for worker services
resource "aws_ecs_service" "worker" {
  for_each = local.enabled_worker_services

  name             = "${var.app_name}-${var.environment}-${each.key}"
  cluster          = module.ecs.cluster_id
  task_definition  = aws_ecs_task_definition.worker[each.key].arn
  desired_count    = each.value.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.private_subnets
    assign_public_ip = false
  }

  # Enable ECS Exec for debugging
  enable_execute_command = true

  # Optional health check grace period
  health_check_grace_period_seconds = each.value.health_check_grace

  # Optional deployment configuration
  deployment_minimum_healthy_percent = lookup(each.value.deployment_config, "min_healthy_percent", null)
  deployment_maximum_percent         = lookup(each.value.deployment_config, "max_percent", null)

  dynamic "deployment_circuit_breaker" {
    for_each = lookup(each.value.deployment_config, "circuit_breaker", null) != null ? [1] : []
    content {
      enable   = lookup(each.value.deployment_config.circuit_breaker, "enable", true)
      rollback = lookup(each.value.deployment_config.circuit_breaker, "rollback", true)
    }
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-${each.key}-service"
  })
}