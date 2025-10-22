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

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory for the container in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

# ========================================
# Database Configuration
# ========================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial storage allocation for RDS (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling (GB). Set to 0 to disable. Recommended: 100+ for production"
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
  description = "Create a read replica for the RDS instance (useful for reporting/analytics)"
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
# OPTIONAL: Email (SES)
# ========================================

variable "enable_ses" {
  description = "Enable AWS SES for sending emails"
  type        = bool
  default     = true
}

variable "ses_test_emails" {
  description = "List of test email addresses for SES sandbox"
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
