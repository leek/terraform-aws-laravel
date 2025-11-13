variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS security group ID"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "s3_filesystem_bucket_name" {
  description = "S3 filesystem bucket name"
  type        = string
}

variable "sqs_queue_name" {
  description = "SQS queue name"
  type        = string
}

variable "caller_identity_account_id" {
  description = "AWS account ID"
  type        = string
}

# ========================================
# Web Service Configuration
# ========================================

variable "container_cpu" {
  description = "CPU units for the web service container (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory (MB) for the web service container"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of web service tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum capacity for web service auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity for web service auto scaling"
  type        = number
  default     = 10
}

# ========================================
# Scheduled Scaling Configuration
# ========================================

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling to reduce costs during off-hours (nights and weekends)"
  type        = bool
  default     = false
}

variable "scale_down_schedule" {
  description = "Cron expression for scaling down (UTC time). Default: 6 PM EST weekdays + all day weekends"
  type        = string
  default     = "cron(0 23 ? * MON-FRI *)" # 6 PM EST Mon-Fri (11 PM UTC)
}

variable "scale_up_schedule" {
  description = "Cron expression for scaling up (UTC time). Default: 8 AM EST weekdays only"
  type        = string
  default     = "cron(0 12 ? * MON-FRI *)" # 8 AM EST Mon-Fri (12 PM UTC)
}

variable "weekend_scale_down_schedule" {
  description = "Cron expression for weekend scale down (UTC time). Default: Saturday 12 AM EST"
  type        = string
  default     = "cron(0 5 ? * SAT *)" # Saturday 12 AM EST (5 AM UTC)
}

# ========================================
# Queue Worker Configuration
# ========================================

variable "queue_worker_cpu" {
  description = "CPU units for the queue worker container (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "queue_worker_memory" {
  description = "Memory (MB) for the queue worker container"
  type        = number
  default     = 1024
}

variable "queue_worker_desired_count" {
  description = "Desired number of queue worker tasks"
  type        = number
  default     = 1
}

# ========================================
# Scheduler Configuration
# ========================================

variable "scheduler_cpu" {
  description = "CPU units for the scheduler container (256 = 0.25 vCPU, 512 = 0.5 vCPU)"
  type        = number
  default     = 256
}

variable "scheduler_memory" {
  description = "Memory (MB) for the scheduler container"
  type        = number
  default     = 512
}

variable "scheduler_desired_count" {
  description = "Desired number of scheduler tasks (typically 1)"
  type        = number
  default     = 1
}

variable "meilisearch_host" {
  description = "Meilisearch host"
  type        = string
}

variable "meilisearch_master_key" {
  description = "Meilisearch master key"
  type        = string
  sensitive   = true
}

variable "redis_endpoint" {
  description = "Redis endpoint"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
}

variable "additional_environment_variables" {
  description = "Additional environment variables to add to ECS task definition"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "enable_queue_worker" {
  description = "Enable the queue worker service"
  type        = bool
  default     = true
}

variable "enable_scheduler" {
  description = "Enable the scheduler service"
  type        = bool
  default     = true
}

variable "app_server_mode" {
  description = "Application server mode. Valid values: 'php-fpm', 'octane-swoole', 'octane-roadrunner', and 'octane-frankenphp'."
  type        = string
  default     = "php-fpm"
}

# ========================================
# Laravel Nightwatch Configuration
# ========================================

variable "enable_nightwatch" {
  description = "Enable Laravel Nightwatch monitoring sidecar container"
  type        = bool
  default     = false
}

variable "nightwatch_token" {
  description = "Laravel Nightwatch token from nightwatch.laravel.com dashboard (used as NIGHTWATCH_TOKEN for both app and agent)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "nightwatch_request_sample_rate" {
  description = "Request sample rate for Nightwatch (0.0 to 1.0)"
  type        = number
  default     = 0.1
}

variable "nightwatch_command_sample_rate" {
  description = "Command sample rate for Nightwatch (0.0 to 1.0)"
  type        = number
  default     = 1.0
}

variable "nightwatch_exception_sample_rate" {
  description = "Exception sample rate for Nightwatch (0.0 to 1.0)"
  type        = number
  default     = 1.0
}

variable "nightwatch_agent_image" {
  description = "Docker image for Nightwatch agent"
  type        = string
  default     = "laravelphp/nightwatch-agent:v1"
}

variable "nightwatch_agent_cpu" {
  description = "CPU units for Nightwatch agent sidecar"
  type        = number
  default     = 128
}

variable "nightwatch_agent_memory" {
  description = "Memory (MB) for Nightwatch agent sidecar"
  type        = number
  default     = 256
}
