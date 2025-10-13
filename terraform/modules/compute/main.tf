# ========================================
# ECS Cluster
# ========================================

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

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${var.ecr_repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = concat([
        # Dynamic/computed environment variables only
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
          name  = "REDIS_HOST"
          value = var.redis_endpoint
        },
        {
          name  = "REDIS_PORT"
          value = tostring(var.redis_port)
        },
        {
          name  = "SQS_QUEUE"
          value = var.sqs_queue_name
        },
        {
          name  = "SQS_PREFIX"
          value = "https://sqs.${var.aws_region}.amazonaws.com/${var.caller_identity_account_id}"
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
          value = "https://${var.s3_filesystem_bucket_name}.s3.${var.aws_region}.amazonaws.com"
        }
      ], var.additional_environment_variables)

      secrets = [
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
          name      = "SENTRY_LARAVEL_DSN"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/SENTRY_LARAVEL_DSN"
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

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

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

  # Give Laravel time to boot before health checks start
  health_check_grace_period_seconds = 120

  # Enable ECS Exec for debugging
  enable_execute_command = true

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
