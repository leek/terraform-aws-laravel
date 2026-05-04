# ========================================
# Locals - Shared Configuration
# ========================================

locals {
  # Nightwatch configuration
  # Use the token from the dashboard as the NIGHTWATCH_TOKEN
  # This token is used for both app->agent and agent->cloud authentication
  nightwatch_token = var.enable_nightwatch ? var.nightwatch_token : ""

  nightwatch_agent_is_ecr = can(regex("(\\.dkr\\.ecr\\.|^public\\.ecr\\.aws/)", var.nightwatch_agent_image))
  nightwatch_repository_credentials = (var.dockerhub_credentials_secret_arn != "" && !local.nightwatch_agent_is_ecr) ? {
    repositoryCredentials = { credentialsParameter = var.dockerhub_credentials_secret_arn }
  } : {}

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
      name  = "DB_CONNECTION"
      value = var.db_connection
    },
    {
      name  = "DB_PORT"
      value = tostring(var.db_port)
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
      name  = "REDIS_SCHEME"
      value = "tls"
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
      value = var.mail_from_name
    },
    {
      name  = "AWS_SES_REGION"
      value = var.aws_region
    },
    {
      name  = "SES_CONFIGURATION_SET"
      value = var.ses_configuration_set_name
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
      value = var.cloudfront_domain != "" ? "https://${var.cloudfront_domain}/public" : "https://${var.s3_filesystem_bucket_name}.s3.${var.aws_region}.amazonaws.com"
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
  common_secrets = concat([
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
    },
    {
      name      = "REDIS_PASSWORD"
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/REDIS_PASSWORD"
    }
    ], [
    for name in var.additional_secret_environment_variable_names : {
      name      = name
      valueFrom = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/${name}"
    }
  ])

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

  # Queue worker autoscaling configuration
  queue_worker_autoscaling_enabled = (
    contains(keys(local.enabled_worker_services), "queue-worker") &&
    length(var.sqs_queue_full_names) > 0
  )
}