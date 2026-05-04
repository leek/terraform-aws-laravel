# ========================================
# Locals - Shared Configuration
# ========================================

locals {
  # Nightwatch configuration
  # Use the token from the dashboard as the NIGHTWATCH_TOKEN
  # This token is used for both app->agent and agent->cloud authentication
  nightwatch_token = var.enable_nightwatch ? var.nightwatch_token : ""

  # Common environment variables shared across all containers
  common_environment_variables = concat([
    {
      name  = "APP_ENV"
      value = var.environment
    },
    {
      name  = "APP_DOMAIN"
      value = var.domain_name
    },
    {
      name  = "APP_URL"
      value = "https://${var.domain_name}"
    },
    {
      name  = "APP_SERVER_MODE"
      value = var.app_server_mode
    },
    {
      name  = "SESSION_DOMAIN"
      value = ".${var.domain_name}"
    },
    {
      name  = "SESSION_COOKIE"
      value = "${var.app_name}_session_${var.environment}"
    },
    {
      name  = "REDIS_HOST"
      value = var.redis_endpoint
    },
    {
      name  = "REDIS_PORT"
      value = tostring(var.redis_port)
    },
    {
      name  = "SQS_QUEUE"
      value = "default"
    },
    {
      name  = "SQS_PREFIX"
      value = "https://sqs.${var.aws_region}.amazonaws.com/${var.caller_identity_account_id}"
    },
    {
      name  = "SQS_SUFFIX"
      value = var.sqs_suffix
    },
    {
      name  = "QUEUE_NAMES"
      value = var.sqs_queue_names_csv
    },
    {
      name  = "AWS_BUCKET"
      value = var.s3_filesystem_bucket_name
    },
    {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    },
    {
      name  = "MAIL_FROM_ADDRESS"
      value = "noreply@${var.domain_name}"
    },
    {
      name  = "MAIL_FROM_NAME"
      value = var.app_name
    },
    {
      name  = "AWS_SES_REGION"
      value = var.aws_region
    },
    {
      name  = "SCOUT_DRIVER"
      value = var.meilisearch_host != "" ? "meilisearch" : "null"
    },
    {
      name  = "MEILISEARCH_HOST"
      value = var.meilisearch_host
    },
    {
      name  = "MEILISEARCH_KEY"
      value = var.meilisearch_master_key
    },
    {
      name  = "AWS_URL"
      value = var.cloudfront_domain != "" ? "https://${var.cloudfront_domain}" : "https://${var.s3_filesystem_bucket_name}.s3.${var.aws_region}.amazonaws.com"
    },
    {
      name  = "PUBLIC_DISK_DRIVER"
      value = "s3"
    },
    {
      name  = "PUBLIC_DISK_ROOT"
      value = "public"
    },
    {
      name  = "PUBLIC_DISK_URL"
      value = var.cloudfront_domain != "" ? "https://${var.cloudfront_domain}" : "https://${var.s3_filesystem_bucket_name}.s3.${var.aws_region}.amazonaws.com"
    },
    {
      name  = "PUBLIC_DISK_SSE"
      value = "AES256"
    },
    {
      name  = "PRIVATE_DISK_DRIVER"
      value = "s3"
    },
    {
      name  = "PRIVATE_DISK_ROOT"
      value = "private"
    }
    ], var.additional_environment_variables, [
    {
      name  = "NIGHTWATCH_ENABLED"
      value = var.enable_nightwatch ? "true" : "false"
    }
    ], var.enable_nightwatch ? [
    {
      name  = "NIGHTWATCH_TOKEN"
      value = local.nightwatch_token
    },
    {
      name  = "NIGHTWATCH_REQUEST_SAMPLE_RATE"
      value = tostring(var.nightwatch_request_sample_rate)
    },
    {
      name  = "NIGHTWATCH_COMMAND_SAMPLE_RATE"
      value = tostring(var.nightwatch_command_sample_rate)
    },
    {
      name  = "NIGHTWATCH_EXCEPTION_SAMPLE_RATE"
      value = tostring(var.nightwatch_exception_sample_rate)
    }
  ] : [])

  # Common secrets shared across all containers
  common_secrets = [
    {
      name      = "APP_KEY"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/APP_KEY"
    },
    {
      name      = "DB_HOST"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/DB_HOST"
    },
    {
      name      = "DB_DATABASE"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/DB_DATABASE"
    },
    {
      name      = "DB_USERNAME"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/DB_USERNAME"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/DB_PASSWORD"
    },
    {
      name      = "DB_READ_HOST"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/DB_READ_HOST"
    },
    {
      name      = "DB_WRITE_HOST"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/DB_HOST"
    },
    {
      name      = "AWS_ACCESS_KEY_ID"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/AWS_ACCESS_KEY_ID"
    },
    {
      name      = "AWS_SECRET_ACCESS_KEY"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/AWS_SECRET_ACCESS_KEY"
    }
  ]

  # Worker services configuration (queue-worker and scheduler)
  worker_services = {
    queue-worker = {
      enabled            = var.enable_queue_worker
      container_role     = "queue-worker"
      cpu                = var.queue_worker_cpu
      memory             = var.queue_worker_memory
      desired_count      = var.queue_worker_desired_count
      port_mappings      = []
      health_check_grace = null
      deployment_config  = {}
      log_stream_prefix  = "queue-worker"
    }
    scheduler = {
      enabled            = var.enable_scheduler
      container_role     = "scheduler"
      cpu                = var.scheduler_cpu
      memory             = var.scheduler_memory
      desired_count      = var.scheduler_desired_count
      port_mappings      = []
      health_check_grace = null
      deployment_config  = {}
      log_stream_prefix  = "scheduler"
    }
  }

  # Filter to only enabled worker services
  enabled_worker_services = {
    for k, v in local.worker_services : k => v if v.enabled
  }
}

# ========================================
# ECS Cluster
# ========================================

#checkov:skip=CKV_TF_1:Version constraint provides better balance between reproducibility and maintainability
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = "${var.app_name}-${var.environment}"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = var.log_group_name
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  tags = var.common_tags
}

# ========================================
# ECS Task Definition
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
    {
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
    }
  ] : []))

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-task"
  })
}

# ========================================
# ECS Service
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

# ========================================
# Auto Scaling
# ========================================

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${module.ecs.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.common_tags
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "${var.app_name}-${var.environment}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "${var.app_name}-${var.environment}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# ========================================
# Scheduled Scaling for Off-Hours Cost Savings
# ========================================

# Scale down to minimum capacity after business hours (weekday evenings)
# Default: 6 PM EST Mon-Fri (11 PM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_down_evening" {
  count = var.enable_scheduled_scaling ? 1 : 0

  name               = "${var.app_name}-${var.environment}-scale-down-evening"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = var.scale_down_schedule

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.min_capacity + 1 # Limit scale-out during off-hours
  }
}

# Scale up before business hours (weekday mornings)
# Default: 8 AM EST Mon-Fri (12 PM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_up_morning" {
  count = var.enable_scheduled_scaling ? 1 : 0

  name               = "${var.app_name}-${var.environment}-scale-up-morning"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = var.scale_up_schedule

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity # Full scale-out capacity during business hours
  }
}

# Scale down for weekends
# Default: Saturday 12 AM EST (5 AM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_down_weekend" {
  count = var.enable_scheduled_scaling ? 1 : 0

  name               = "${var.app_name}-${var.environment}-scale-down-weekend"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = var.weekend_scale_down_schedule

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.min_capacity + 1 # Limit scale-out during weekends
  }
}

# ========================================
# Worker Services (Queue Worker & Scheduler)
# ========================================

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
    {
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
    }
  ] : []))

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-${each.key}-task"
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

# ========================================
# Queue Worker Auto Scaling (SQS-driven)
# ========================================

locals {
  queue_worker_autoscaling_enabled = (
    contains(keys(local.enabled_worker_services), "queue-worker") &&
    length(var.sqs_queue_full_names) > 0
  )
}

resource "aws_appautoscaling_target" "queue_worker" {
  count = local.queue_worker_autoscaling_enabled ? 1 : 0

  max_capacity       = var.queue_worker_max_capacity
  min_capacity       = var.queue_worker_min_capacity
  resource_id        = "service/${module.ecs.cluster_name}/${aws_ecs_service.worker["queue-worker"].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.common_tags
}

resource "aws_appautoscaling_policy" "queue_worker_age" {
  count = local.queue_worker_autoscaling_enabled ? 1 : 0

  name               = "${var.app_name}-${var.environment}-queue-worker-age-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.queue_worker[0].resource_id
  scalable_dimension = aws_appautoscaling_target.queue_worker[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.queue_worker[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.queue_worker_target_age_seconds

    customized_metric_specification {
      dynamic "metrics" {
        for_each = var.sqs_queue_full_names
        content {
          id          = "m${metrics.key}"
          label       = "AgeOldest_${metrics.value}"
          return_data = false

          metric_stat {
            stat = "Maximum"

            metric {
              namespace   = "AWS/SQS"
              metric_name = "ApproximateAgeOfOldestMessage"

              dimensions {
                name  = "QueueName"
                value = metrics.value
              }
            }
          }
        }
      }

      metrics {
        id          = "max_age"
        label       = "MaxAgeAcrossQueues"
        return_data = true
        expression  = "MAX([${join(",", [for i, _ in var.sqs_queue_full_names : "m${i}"])}])"
      }
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
