# ========================================
# Meilisearch Security Group
# ========================================

resource "aws_security_group" "meilisearch" {
  name_prefix = "${var.app_name}-${var.environment}-meilisearch-"
  vpc_id      = var.vpc_id

  ingress {
    description = "Meilisearch HTTP from ECS"
    from_port   = 7700
    to_port     = 7700
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block] # Allow from VPC CIDR
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-meilisearch-sg"
  })
}

# ========================================
# Meilisearch Task Definition
# ========================================

resource "aws_ecs_task_definition" "meilisearch" {
  family                   = "${var.app_name}-${var.environment}-meilisearch"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "meilisearch"
      image     = "getmeili/meilisearch:v1.5"
      essential = true

      portMappings = [
        {
          containerPort = 7700
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "MEILI_MASTER_KEY"
          value = var.meilisearch_master_key
        },
        {
          name  = "MEILI_ENV"
          value = var.environment == "production" ? "production" : "development"
        },
        {
          name  = "MEILI_HTTP_ADDR"
          value = "0.0.0.0:7700"
        },
        {
          name  = "MEILI_LOG_LEVEL"
          value = "INFO"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "meilisearch"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:7700/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-meilisearch-task"
  })
}

# ========================================
# Service Discovery
# ========================================

resource "aws_service_discovery_private_dns_namespace" "meilisearch" {
  name = "${var.app_name}-${var.environment}.local"
  vpc  = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-meilisearch-namespace"
  })
}

resource "aws_service_discovery_service" "meilisearch" {
  name = "meilisearch"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.meilisearch.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-meilisearch-discovery"
  })
}

# ========================================
# Meilisearch Service with Service Discovery
# ========================================

resource "aws_ecs_service" "meilisearch" {
  name             = "${var.app_name}-${var.environment}-meilisearch"
  cluster          = var.ecs_cluster_id
  task_definition  = aws_ecs_task_definition.meilisearch.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    security_groups  = [aws_security_group.meilisearch.id]
    subnets          = var.private_subnets
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.meilisearch.arn
  }

  # Enable ECS Exec for debugging
  enable_execute_command = true

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-meilisearch-service"
  })
}
