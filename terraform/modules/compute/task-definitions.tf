# ========================================
# ECS Task Definitions
# ========================================

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.app_name}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode(concat([
    {
      name      = "app"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = local.common_environment_variables
      secrets     = local.common_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
        }
      }
    }
    ], var.enable_nightwatch ? [
    merge({
      name      = "nightwatch-agent"
      image     = var.nightwatch_agent_image
      essential = false
      cpu       = var.nightwatch_agent_cpu
      memory    = var.nightwatch_agent_memory

      portMappings = [
        {
          containerPort = 2407
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NIGHTWATCH_TOKEN"
          value = local.nightwatch_token
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "nightwatch"
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
        }
      }
    }, local.nightwatch_repository_credentials)
  ] : []))

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-task"
  })
}

# Task Definitions for worker services
resource "aws_ecs_task_definition" "worker" {
  for_each = local.enabled_worker_services

  family                   = "${var.app_name}-${var.environment}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode(concat([
    {
      name      = each.key
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = each.value.port_mappings

      environment = concat([
        {
          name  = "CONTAINER_ROLE"
          value = each.value.container_role
        }
      ], local.common_environment_variables)

      secrets = local.common_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.value.log_stream_prefix
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
        }
      }
    }
    ], var.enable_nightwatch ? [
    merge({
      name      = "nightwatch-agent"
      image     = var.nightwatch_agent_image
      essential = false
      cpu       = var.nightwatch_agent_cpu
      memory    = var.nightwatch_agent_memory

      portMappings = [
        {
          containerPort = 2407
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NIGHTWATCH_TOKEN"
          value = local.nightwatch_token
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "nightwatch-${each.key}"
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
        }
      }
    }, local.nightwatch_repository_credentials)
  ] : []))

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-${each.key}-task"
  })
}