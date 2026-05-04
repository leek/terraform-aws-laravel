# ========================================
# REQUIRED: Basic Configuration
# ========================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "laravel-app"
}

variable "app_key" {
  description = "Laravel application key (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "additional_secret_environment_variables" {
  description = "Additional secret env vars to store as SSM SecureString parameters and expose to ECS task definitions"
  type = list(object({
    name  = string
    value = string
  }))
  default   = []
  sensitive = true

  validation {
    condition     = length(var.additional_secret_environment_variables) == length(distinct([for secret in var.additional_secret_environment_variables : secret.name]))
    error_message = "additional_secret_environment_variables must not contain duplicate names."
  }
}

variable "environment" {
  description = "Environment name. Must match the selected Terraform workspace."
  type        = string

  validation {
    condition     = contains(["staging", "uat", "production"], var.environment)
    error_message = "environment must be one of: staging, uat, or production."
  }
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "manage_route53_dns" {
  description = "Create Route53 DNS records for certificates, ALB, SES, and DMARC. Set false when DNS is managed externally."
  type        = bool
  default     = true
}

variable "route53_zone_id" {
  description = "Existing Route53 hosted zone ID. Leave empty to look up by root domain when manage_route53_dns is true."
  type        = string
  default     = ""
}

variable "wait_for_acm_validation" {
  description = "Wait for ACM DNS validation before creating certificate-dependent resources. Defaults to manage_route53_dns."
  type        = bool
  default     = null
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN for the primary app domain. Empty requests one through this module."
  type        = string
  default     = ""
}

variable "vpn_server_certificate_arn" {
  description = "Existing ACM certificate ARN for the Client VPN server domain. Empty requests one through this module."
  type        = string
  default     = ""
}

variable "vanity_domains" {
  description = "External vanity domains to certificate and redirect through the ALB"
  type = list(object({
    domain          = string
    redirect_host   = string
    redirect_path   = optional(string, "/")
    certificate_arn = optional(string, "")
  }))
  default = []
}

variable "github_org" {
  description = "GitHub organization/username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "enable_bedrock" {
  description = "Enable AWS Bedrock access for ECS tasks and the Laravel IAM user"
  type        = bool
  default     = false
}

variable "bedrock_region" {
  description = "AWS region for Bedrock. Leave empty to use aws_region."
  type        = string
  default     = ""
}

variable "dockerhub_username" {
  description = "Docker Hub username for authenticated image pulls. Empty disables secret creation."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dockerhub_access_token" {
  description = "Docker Hub personal access token for authenticated image pulls. Empty disables secret creation."
  type        = string
  default     = ""
  sensitive   = true
}

# ========================================
# REQUIRED: Database Credentials
# ========================================

variable "app_db_password" {
  description = "Password for the application database user"
  type        = string
  sensitive   = true
}

variable "db_read_only_password" {
  description = "Password for the read-only reporting database user"
  type        = string
  sensitive   = true
}

# ========================================
# OPTIONAL: Search Configuration
# ========================================

variable "meilisearch_master_key" {
  description = "Meilisearch master key for authentication (only required if enable_meilisearch = true)"
  type        = string
  sensitive   = true
  default     = ""
}

# ========================================
# Container Configuration
# ========================================

# Web Service (handles HTTP requests)
variable "container_cpu" {
  description = "CPU units for the web service container (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory for the web service container in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of web service tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of web service tasks for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of web service tasks for auto scaling"
  type        = number
  default     = 10
}

# Application Server Mode
variable "app_server_mode" {
  description = "Application server mode: 'php-fpm' (default), 'octane-swoole', 'octane-frankenphp', or 'octane-roadrunner'. Octane modes provide better performance for Laravel applications."
  type        = string
  default     = "php-fpm"
  validation {
    condition     = contains(["php-fpm", "octane-swoole", "octane-frankenphp", "octane-roadrunner"], var.app_server_mode)
    error_message = "app_server_mode must be one of: 'php-fpm', 'octane-swoole', 'octane-frankenphp', or 'octane-roadrunner'"
  }
}

# Queue Worker (processes background jobs)
variable "queue_worker_cpu" {
  description = "CPU units for the queue worker container (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "queue_worker_memory" {
  description = "Memory for the queue worker container in MB"
  type        = number
  default     = 1024
}

variable "queue_worker_desired_count" {
  description = "Desired number of queue worker tasks"
  type        = number
  default     = 1
}

variable "queue_worker_min_capacity" {
  description = "Minimum number of queue worker tasks for SQS-driven autoscaling"
  type        = number
  default     = 1
}

variable "queue_worker_max_capacity" {
  description = "Maximum number of queue worker tasks for SQS-driven autoscaling"
  type        = number
  default     = 5
}

variable "queue_worker_target_age_seconds" {
  description = "Target maximum age in seconds for the oldest SQS message before queue workers scale out"
  type        = number
  default     = 60
}

# Scheduler (runs Laravel's cron/scheduled tasks)
variable "scheduler_cpu" {
  description = "CPU units for the scheduler container (256 = 0.25 vCPU, 512 = 0.5 vCPU)"
  type        = number
  default     = 256
}

variable "scheduler_memory" {
  description = "Memory for the scheduler container in MB"
  type        = number
  default     = 512
}

variable "scheduler_desired_count" {
  description = "Desired number of scheduler tasks (typically 1)"
  type        = number
  default     = 1
}

# Queue Names
variable "queue_names" {
  description = "Logical queue names for SQS. Each becomes a separate SQS queue."
  type        = list(string)
  default     = ["default"]
}

variable "image_tag" {
  description = "Container image tag used by Terraform-created ECS task definitions. Deploy tooling can register later task-definition revisions pinned to immutable tags."
  type        = string
  default     = "latest"
}

# ========================================
# Database Configuration
# ========================================

variable "db_engine" {
  description = "Database engine: mysql, mariadb, postgres, aurora-mysql, or aurora-postgresql. Aurora provides better scalability and high availability."
  type        = string
  default     = "mysql"
  validation {
    condition     = contains(["mysql", "mariadb", "postgres", "aurora-mysql", "aurora-postgresql"], var.db_engine)
    error_message = "db_engine must be one of: mysql, mariadb, postgres, aurora-mysql, or aurora-postgresql"
  }
}

variable "db_engine_version" {
  description = "Database engine version. Leave empty to use default version for selected engine. Defaults: MySQL 8.4.8, MariaDB 10.11.9, PostgreSQL 18.3, Aurora MySQL 8.0.mysql_aurora.3.07.1, Aurora PostgreSQL 18.3"
  type        = string
  default     = ""
}

variable "db_master_username" {
  description = "Database master username. Leave empty for engine-specific default (admin for MySQL/MariaDB, postgres_admin for PostgreSQL)."
  type        = string
  default     = ""
}

variable "enable_postgres_audit" {
  description = "Enable PostgreSQL audit-oriented parameter group settings when using PostgreSQL engines"
  type        = bool
  default     = true
}

variable "db_cloudwatch_log_retention_days" {
  description = "Retention in days for database CloudWatch log groups. Null uses 30 days in production and 7 days elsewhere."
  type        = number
  default     = null
}

variable "db_instance_class" {
  description = "RDS/Aurora instance class. For Aurora Serverless v2, use db.serverless"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial storage allocation for RDS (GB). Not applicable for Aurora."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling (GB). Set to 0 to disable. Recommended: 100+ for production. Not applicable for Aurora."
  type        = number
  default     = 0
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights (not supported on t3.micro/small)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection (recommended for production)"
  type        = bool
  default     = false
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for high availability (recommended for production)"
  type        = bool
  default     = false
}

variable "db_create_read_replica" {
  description = "Create a read replica for the RDS instance (useful for reporting/analytics). For Aurora, use reader endpoint instead."
  type        = bool
  default     = false
}

variable "db_read_replica_instance_class" {
  description = "Instance class for read replica (defaults to primary instance class if not specified)"
  type        = string
  default     = ""
}

variable "app_db_username" {
  description = "Username for the application database user (created by bastion)"
  type        = string
  default     = "app_user"
}

# Aurora-specific configuration
variable "aurora_enable_serverlessv2" {
  description = "Enable Aurora Serverless v2 for automatic scaling (only for Aurora engines). Provides cost optimization and automatic capacity scaling."
  type        = bool
  default     = false
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora Capacity Units (ACUs) for Serverless v2. 0.5 to 128 in 0.5 increments. Each ACU provides ~2GB RAM."
  type        = number
  default     = 0.5
  validation {
    condition     = var.aurora_min_capacity >= 0.5 && var.aurora_min_capacity <= 128 && floor(var.aurora_min_capacity * 2) == var.aurora_min_capacity * 2
    error_message = "aurora_min_capacity must be between 0.5 and 128 in 0.5 increments"
  }
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora Capacity Units (ACUs) for Serverless v2. 0.5 to 128 in 0.5 increments."
  type        = number
  default     = 1.0
  validation {
    condition     = var.aurora_max_capacity >= 0.5 && var.aurora_max_capacity <= 128 && floor(var.aurora_max_capacity * 2) == var.aurora_max_capacity * 2 && var.aurora_max_capacity >= var.aurora_min_capacity
    error_message = "aurora_max_capacity must be between 0.5 and 128 in 0.5 increments and must be >= aurora_min_capacity"
  }
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances to create (only for non-serverless Aurora). Minimum 1 for single-AZ, 2+ for Multi-AZ."
  type        = number
  default     = 1
  validation {
    condition     = var.aurora_instance_count >= 1
    error_message = "aurora_instance_count must be at least 1"
  }
}

# ========================================
# Redis/ElastiCache Configuration
# ========================================

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache clusters for the Redis replication group. 2+ enables automatic failover and Multi-AZ."
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_apply_immediately" {
  description = "Apply Redis changes immediately instead of waiting for the maintenance window"
  type        = bool
  default     = false
}

# ========================================
# Network Configuration
# ========================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all private subnets. Set false for one NAT gateway per AZ."
  type        = bool
  default     = true
}

variable "enable_vpc_interface_endpoints" {
  description = "Create VPC interface endpoints for private AWS service access"
  type        = bool
  default     = true
}

variable "enabled_vpc_interface_endpoints" {
  description = "AWS service endpoint short names to create when enable_vpc_interface_endpoints is true"
  type        = list(string)
  default     = ["ssm", "ssmmessages", "ec2messages", "ecr.api", "ecr.dkr", "logs", "sqs"]
}

variable "rds_additional_ingress_cidrs" {
  description = "Additional CIDR blocks allowed to connect to RDS/Aurora"
  type        = list(string)
  default     = []
}

variable "rds_additional_ingress_security_group_ids" {
  description = "Additional security group IDs allowed to connect to RDS/Aurora"
  type        = list(string)
  default     = []
}

# ========================================
# OPTIONAL: Bastion Host
# ========================================

variable "enable_bastion" {
  description = "Enable bastion host for database access"
  type        = bool
  default     = false
}

variable "ec2_key_name" {
  description = "EC2 Key Pair name for bastion host"
  type        = string
  default     = ""
}

variable "bastion_instance_type" {
  description = "Bastion host instance type"
  type        = string
  default     = "t3.nano"
}

variable "bastion_allowed_ips" {
  description = "List of IPs allowed to SSH to bastion (CIDR format)"
  type        = list(string)
  default     = []
}

variable "enable_bastion_database_bootstrap" {
  description = "Run bastion user data that creates/updates application and read-only database users"
  type        = bool
  default     = false
}

variable "enable_bastion_scheduled_stop" {
  description = "Enable EventBridge schedules to stop the bastion off-hours and start it for business hours"
  type        = bool
  default     = false
}

variable "bastion_stop_schedule" {
  description = "Cron expression for stopping the bastion"
  type        = string
  default     = "cron(0 23 ? * MON-FRI *)"
}

variable "bastion_start_schedule" {
  description = "Cron expression for starting the bastion"
  type        = string
  default     = "cron(0 12 ? * MON-FRI *)"
}

variable "bastion_schedule_timezone" {
  description = "IANA timezone name for bastion stop/start schedules"
  type        = string
  default     = "UTC"
}

# ========================================
# OPTIONAL: Client VPN
# ========================================

variable "enable_client_vpn" {
  description = "Enable AWS Client VPN endpoint"
  type        = bool
  default     = false
}

variable "vpn_client_cidr_block" {
  description = "CIDR block for VPN client IP addresses"
  type        = string
  default     = "10.4.0.0/22"
}

variable "vpn_dns_servers" {
  description = "DNS servers for VPN clients"
  type        = list(string)
  default     = ["10.0.0.2"]
}

variable "vpn_split_tunnel" {
  description = "Enable split tunneling for VPN"
  type        = bool
  default     = true
}

variable "vpn_saml_provider_arn" {
  description = "ARN of SAML provider for VPN authentication (leave empty for certificate-based auth)"
  type        = string
  default     = ""
}

variable "vpn_connection_log_enabled" {
  description = "Enable VPN connection logging"
  type        = bool
  default     = false
}

variable "vpn_cloudwatch_log_group" {
  description = "CloudWatch log group for VPN logs"
  type        = string
  default     = "/AWSVPN"
}

variable "vpn_cloudwatch_log_stream" {
  description = "CloudWatch log stream for VPN logs"
  type        = string
  default     = "VPNAccess"
}

variable "vpn_login_banner_enabled" {
  description = "Enable VPN login banner"
  type        = bool
  default     = true
}

variable "vpn_login_banner_text" {
  description = "VPN login banner text"
  type        = string
  default     = "Authorized Access Only"
}

variable "vpn_additional_authorized_cidrs" {
  description = "Additional CIDR blocks to authorize for VPN access"
  type        = list(string)
  default     = []
}

# ========================================
# OPTIONAL: Meilisearch
# ========================================

variable "enable_meilisearch" {
  description = "Enable Meilisearch search engine"
  type        = bool
  default     = true
}

# ========================================
# OPTIONAL: Laravel Nightwatch
# ========================================

variable "enable_nightwatch" {
  description = "Enable Laravel Nightwatch monitoring as a sidecar container"
  type        = bool
  default     = false
}

variable "enable_nightwatch_agent_mirror" {
  description = "Create an ECR repository for mirroring the Laravel Nightwatch agent image"
  type        = bool
  default     = false
}

variable "nightwatch_token" {
  description = "Laravel Nightwatch token from nightwatch.laravel.com (only required if enable_nightwatch = true)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "nightwatch_request_sample_rate" {
  description = "Request sample rate for Nightwatch (0.0 to 1.0). Example: 0.1 = 10% of requests"
  type        = number
  default     = 0.1
  validation {
    condition     = var.nightwatch_request_sample_rate >= 0 && var.nightwatch_request_sample_rate <= 1
    error_message = "Request sample rate must be between 0.0 and 1.0"
  }
}

variable "nightwatch_command_sample_rate" {
  description = "Command sample rate for Nightwatch (0.0 to 1.0). Example: 1.0 = 100% of commands"
  type        = number
  default     = 1.0
  validation {
    condition     = var.nightwatch_command_sample_rate >= 0 && var.nightwatch_command_sample_rate <= 1
    error_message = "Command sample rate must be between 0.0 and 1.0"
  }
}

variable "nightwatch_exception_sample_rate" {
  description = "Exception sample rate for Nightwatch (0.0 to 1.0). Example: 1.0 = 100% of exceptions"
  type        = number
  default     = 1.0
  validation {
    condition     = var.nightwatch_exception_sample_rate >= 0 && var.nightwatch_exception_sample_rate <= 1
    error_message = "Exception sample rate must be between 0.0 and 1.0"
  }
}

variable "nightwatch_agent_image" {
  description = "Docker image for Nightwatch agent"
  type        = string
  default     = "laravelphp/nightwatch-agent:v1"
}

variable "nightwatch_agent_cpu" {
  description = "CPU units for Nightwatch agent sidecar (64 = 0.0625 vCPU, 128 = 0.125 vCPU)"
  type        = number
  default     = 128
}

variable "nightwatch_agent_memory" {
  description = "Memory (MB) for Nightwatch agent sidecar"
  type        = number
  default     = 256
}

# ========================================
# OPTIONAL: Scheduled Scaling (Cost Optimization)
# ========================================

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling to reduce costs during off-hours (nights and weekends). Recommended for staging environments."
  type        = bool
  default     = false
}

variable "scale_down_schedule" {
  description = "Cron expression for scaling down during weekday evenings (UTC time). Default: 6 PM EST Mon-Fri (11 PM UTC)"
  type        = string
  default     = "cron(0 23 ? * MON-FRI *)"
}

variable "scale_up_schedule" {
  description = "Cron expression for scaling up during weekday mornings (UTC time). Default: 8 AM EST Mon-Fri (12 PM UTC)"
  type        = string
  default     = "cron(0 12 ? * MON-FRI *)"
}

variable "weekend_scale_down_schedule" {
  description = "Cron expression for weekend scale down (UTC time). Default: Saturday 12 AM EST (5 AM UTC)"
  type        = string
  default     = "cron(0 5 ? * SAT *)"
}

# ========================================
# OPTIONAL: Email (SES)
# ========================================

variable "enable_ses" {
  description = "Enable AWS SES for sending emails"
  type        = bool
  default     = true
}

variable "ses_test_emails" {
  description = "List of individual test email addresses for SES sandbox (fallback option)"
  type        = list(string)
  default     = []
}

variable "ses_test_email_domains" {
  description = "List of domains to verify for SES sandbox (allows sending to any email at these domains)"
  type        = list(string)
  default     = []
}

variable "ses_mail_from_subdomain" {
  description = "Subdomain label used for the SES custom MAIL FROM domain. Empty string disables custom MAIL FROM."
  type        = string
  default     = "mail"
}

variable "ses_mail_from_behavior_on_mx_failure" {
  description = "SES behavior when the custom MAIL FROM MX record is not resolvable"
  type        = string
  default     = "UseDefaultValue"
}

variable "ses_enable_event_destination" {
  description = "Provision an SNS topic and SES configuration-set event destination for selected events"
  type        = bool
  default     = true
}

variable "ses_event_matching_types" {
  description = "SES event types routed to the SNS events topic"
  type        = list(string)
  default     = ["bounce", "complaint", "reject"]
}

variable "ses_event_notification_emails" {
  description = "Email addresses to subscribe to the SES event SNS topic"
  type        = list(string)
  default     = []
}

variable "ses_enable_account_suppression" {
  description = "Enable SES account-level suppression for bounced/complained recipients"
  type        = bool
  default     = true
}

variable "ses_suppressed_reasons" {
  description = "Reasons that trigger account-level suppression"
  type        = list(string)
  default     = ["BOUNCE", "COMPLAINT"]
}

# ========================================
# OPTIONAL: Monitoring
# ========================================

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for API audit logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "healthcheck_alarm_emails" {
  description = "List of email addresses to notify for health check alarms"
  type        = list(string)
  default     = []
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logging for request traces and WAF triage"
  type        = bool
  default     = false
}

variable "blocked_uri_patterns" {
  description = "List of URI patterns to block at the WAF level (e.g., ['/login/login.html', '/admin.php', '/.env'])"
  type        = list(string)
  default     = []
}

variable "enable_bot_control" {
  description = "Enable AWS WAF Bot Control managed rule set"
  type        = bool
  default     = false
}

variable "rate_limit_general" {
  description = "General WAF request rate limit per IP over a 5-minute window"
  type        = number
  default     = 2000
}

variable "rate_limit_livewire" {
  description = "WAF request rate limit per IP for Livewire endpoints over a 5-minute window"
  type        = number
  default     = 10000
}

variable "rate_limit_excluded_path_prefixes" {
  description = "Additional URI path prefixes excluded from the general rate limit"
  type        = list(string)
  default     = []
}

variable "rate_limit_excluded_exact_paths" {
  description = "Additional exact URI paths excluded from the general rate limit"
  type        = list(string)
  default     = []
}

variable "alb_health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/up"
}

variable "enable_alb_stickiness" {
  description = "Enable ALB target group stickiness"
  type        = bool
  default     = false
}

variable "alb_ssl_policy" {
  description = "ALB HTTPS listener SSL policy"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

# ========================================
# OPTIONAL: CloudFront CDN
# ========================================

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN distribution for S3 assets"
  type        = bool
  default     = false
}

variable "cloudfront_domain" {
  description = "Custom domain for CloudFront distribution (e.g. cdn.example.com). Leave empty to skip."
  type        = string
  default     = ""

  validation {
    condition     = var.cloudfront_domain == "" || can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+[a-zA-Z0-9]$", var.cloudfront_domain))
    error_message = "cloudfront_domain must be a bare domain (no scheme, path, or trailing slash), e.g. cdn.example.com"
  }
}

variable "enable_cloudfront_app" {
  description = "Enable a CloudFront distribution in front of the ALB"
  type        = bool
  default     = false
}

variable "cloudfront_app_aliases" {
  description = "Aliases for the app CloudFront distribution. Requires cloudfront_app_certificate_arn."
  type        = list(string)
  default     = []
}

variable "cloudfront_app_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for app CloudFront aliases. Empty uses the default CloudFront certificate."
  type        = string
  default     = ""
}

variable "cloudfront_app_price_class" {
  description = "CloudFront price class for the app distribution"
  type        = string
  default     = "PriceClass_100"
}

# ========================================
# OPTIONAL: Additional Environment Variables
# ========================================

variable "additional_environment_variables" {
  description = "Additional environment variables to add to ECS task definition. Use this to add custom static env vars without creating new Terraform variables."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# ========================================
# OPTIONAL: Resource Tagging
# ========================================

variable "cost_center" {
  description = "Cost center for resource tagging"
  type        = string
  default     = "Engineering"
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

# ========================================
# OPTIONAL: DNS Configuration
# ========================================

variable "dmarc_record" {
  description = "DMARC TXT record value (only set for production)"
  type        = string
  default     = ""
}

# ========================================
# OPTIONAL: Compliance and Auditing
# ========================================

# AWS Config
variable "enable_aws_config" {
  description = "Enable AWS Config for compliance tracking"
  type        = bool
  default     = true
}

variable "enable_hipaa_rules" {
  description = "Enable HIPAA-specific AWS Config rules"
  type        = bool
  default     = true
}

# AWS Security Hub
variable "enable_security_hub" {
  description = "Enable AWS Security Hub for centralized security findings"
  type        = bool
  default     = true
}

variable "enable_cis_standard" {
  description = "Enable CIS AWS Foundations Benchmark standard in Security Hub"
  type        = bool
  default     = true
}

variable "enable_pci_dss_standard" {
  description = "Enable PCI DSS standard in Security Hub"
  type        = bool
  default     = false
}

variable "enable_aws_foundational_standard" {
  description = "Enable AWS Foundational Security Best Practices standard in Security Hub"
  type        = bool
  default     = true
}

variable "security_hub_notification_emails" {
  description = "Email addresses to notify for critical/high Security Hub findings"
  type        = list(string)
  default     = []
}

# AWS GuardDuty
variable "enable_guardduty" {
  description = "Enable AWS GuardDuty for threat detection"
  type        = bool
  default     = true
}

variable "guardduty_finding_frequency" {
  description = "Frequency of GuardDuty findings (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "FIFTEEN_MINUTES"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_frequency)
    error_message = "Must be one of: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  }
}

variable "guardduty_notification_emails" {
  description = "Email addresses to notify for GuardDuty findings"
  type        = list(string)
  default     = []
}

# AWS Macie (Production Only)
variable "enable_macie" {
  description = "Enable AWS Macie for PHI/PII detection in S3 (production only)"
  type        = bool
  default     = false
}

variable "macie_finding_frequency" {
  description = "Frequency of Macie findings (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "ONE_HOUR"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.macie_finding_frequency)
    error_message = "Must be one of: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  }
}

# IAM Access Analyzer (Production Only)
variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer to identify resources shared with external entities (production only)"
  type        = bool
  default     = false
}

# AWS Backup Audit Manager (Production Only)
variable "enable_backup_audit_manager" {
  description = "Enable AWS Backup Audit Manager for backup compliance auditing (production only)"
  type        = bool
  default     = false
}

variable "enable_hipaa_framework" {
  description = "Enable HIPAA backup compliance framework in Backup Audit Manager"
  type        = bool
  default     = true
}

variable "backup_vault_arn" {
  description = "Backup Vault ARN to audit (required when enable_backup_audit_manager = true)"
  type        = string
  default     = ""
}

# VPC Flow Logs
variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs (required for HIPAA compliance)"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC flow logs"
  type        = number
  default     = 90
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to log (ACCEPT, REJECT, ALL)"
  type        = string
  default     = "ALL"
}
