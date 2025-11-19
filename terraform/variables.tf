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

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "github_org" {
  description = "GitHub organization/username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# ========================================
# REQUIRED: Database Credentials
# ========================================

variable "app_db_password" {
  description = "Password for the application database user"
  type        = string
  sensitive   = true
}

variable "db_reporting_password" {
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
  description = "Database engine version. Leave empty to use default version for selected engine. Defaults: MySQL 8.0.43, MariaDB 10.11.9, PostgreSQL 16.4, Aurora MySQL 8.0.mysql_aurora.3.07.1, Aurora PostgreSQL 16.4"
  type        = string
  default     = ""
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
    condition     = self.value >= 1
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
  description = "Number of cache nodes for Redis"
  type        = number
  default     = 1
}

# ========================================
# Network Configuration
# ========================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
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

# ========================================
# OPTIONAL: Error Tracking (Sentry)
# ========================================

variable "sentry_dsn" {
  description = "Sentry DSN for error tracking"
  type        = string
  default     = ""
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
