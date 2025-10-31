# ========================================
# Laravel AWS Infrastructure Configuration
# ========================================
# This is an example configuration file for deploying a Laravel application to AWS.
# Copy this file and customize it for your environment:
#   cp example.tfvars production.tfvars
#   cp example.tfvars staging.tfvars

# ========================================
# REQUIRED: Basic Configuration
# ========================================

# Your application name (used for resource naming)
app_name = "laravel"

# Environment name (e.g., "production", "staging", "dev")
environment = "production"

# Your application's domain name
domain_name = "example.com"

# Laravel application key (generate with: php artisan key:generate --show)
# IMPORTANT: Keep this secret! Consider using environment variables or a secrets manager.
app_key = "base64:YOUR_APP_KEY_HERE"

# GitHub repository information (used for tagging and OIDC authentication)
github_org  = "your-org"
github_repo = "your-repo"

# ========================================
# AWS Configuration
# ========================================

# AWS region (defaults to us-east-1 if not specified)
# aws_region = "us-east-1"

# ========================================
# REQUIRED: Database Credentials
# ========================================

# Application database user password
# IMPORTANT: Use a strong, randomly generated password
app_db_password = "CHANGE_ME_STRONG_PASSWORD"

# Read-only reporting user password (for analytics/BI tools)
db_reporting_password = "CHANGE_ME_STRONG_PASSWORD"

# ========================================
# OPTIONAL: Search Configuration
# ========================================

# Meilisearch master key (generate random 32+ character string)
# Only required if enable_meilisearch = true
meilisearch_master_key = "CHANGE_ME_MEILISEARCH_KEY"

# ========================================
# Container Configuration
# ========================================

# Valid CPU/Memory combinations for Fargate:
# CPU 256: 512, 1024, 2048
# CPU 512: 1024, 2048, 3072, 4096
# CPU 1024: 2048, 3072, 4096, 5120, 6144, 7168, 8192
# CPU 2048: 4096 to 16384 (1GB increments)
# CPU 4096: 8192 to 30720 (1GB increments)

# Web Service (handles HTTP requests)
container_cpu    = 1024 # CPU units (1024 = 1 vCPU)
container_memory = 2048 # Memory in MB

# Web service scaling configuration
desired_count = 2  # Number of tasks to run
min_capacity  = 1  # Minimum tasks for auto-scaling
max_capacity  = 10 # Maximum tasks for auto-scaling

# Queue Worker (processes background jobs)
queue_worker_cpu           = 512  # CPU units (512 = 0.5 vCPU)
queue_worker_memory        = 1024 # Memory in MB
queue_worker_desired_count = 1    # Number of queue worker tasks

# Scheduler (runs Laravel's cron/scheduled tasks)
scheduler_cpu           = 256 # CPU units (256 = 0.25 vCPU)
scheduler_memory        = 512 # Memory in MB
scheduler_desired_count = 1   # Number of scheduler tasks (typically 1)

# Nightwatch (runs Laravel browser automation and end-to-end tests)
# nightwatch_cpu           = 512  # CPU units (512 = 0.5 vCPU)
# nightwatch_memory        = 1024 # Memory in MB
# nightwatch_desired_count = 0    # Number of Nightwatch tasks (typically 0 or 1, 0 disables)

# ========================================
# Database Configuration
# ========================================

# RDS instance type
# Options: db.t3.micro (free tier), db.t3.small, db.t3.medium, db.t3.large, etc.
db_instance_class = "db.t3.small"

# Initial storage allocation in GB
db_allocated_storage = 20

# Maximum storage for auto-scaling in GB (set to 0 to disable)
# Recommended: 100+ for production
db_max_allocated_storage = 100

# Multi-AZ deployment for high availability (recommended for production)
db_multi_az = false

# Enable Performance Insights (requires db.t3.medium or larger)
enable_performance_insights = false

# Enable deletion protection (highly recommended for production)
enable_deletion_protection = false

# Create a read replica for analytics/reporting queries
db_create_read_replica = false

# Read replica instance class (defaults to same as primary if empty)
db_read_replica_instance_class = ""

# Application database username (created by bastion host)
app_db_username = "app_user"

# ========================================
# Redis/ElastiCache Configuration
# ========================================

# Redis node type
# Options: cache.t3.micro (free tier), cache.t3.small, cache.t3.medium, etc.
redis_node_type = "cache.t3.micro"

# Note: Redis cluster is currently configured as single-node only.
# The num_cache_nodes parameter is not yet implemented.
# For high availability, consider using ElastiCache Replication Groups (future enhancement).

# ========================================
# Network Configuration
# ========================================

# VPC CIDR block - use different ranges for different environments
# Staging:    10.0.0.0/16
# Production: 10.1.0.0/16
vpc_cidr = "10.0.0.0/16"

# ========================================
# OPTIONAL: Bastion Host Configuration
# ========================================

# Enable bastion host for secure database access
enable_bastion = false

# EC2 key pair name (must be created in AWS first)
ec2_key_name = ""

# Bastion instance type (t3.nano is usually sufficient)
bastion_instance_type = "t3.nano"

# IP addresses allowed to SSH to bastion (CIDR format)
# Example: ["203.0.113.0/32", "198.51.100.0/24"]
bastion_allowed_ips = []

# ========================================
# OPTIONAL: Client VPN Configuration
# ========================================
# AWS Client VPN provides secure remote access to your VPC

# Enable Client VPN endpoint
enable_client_vpn = false

# CIDR block for VPN clients (must not overlap with VPC CIDR)
vpn_client_cidr_block = "10.4.0.0/22"

# DNS servers for VPN clients (VPC resolver is at VPC_CIDR +2)
vpn_dns_servers = ["10.0.0.2"]

# Split tunnel (only route VPC traffic through VPN)
vpn_split_tunnel = true

# SAML provider ARN for authentication (must be created in IAM first)
# Leave empty to use certificate-based authentication instead
vpn_saml_provider_arn = ""

# Enable VPN connection logging
vpn_connection_log_enabled = false
vpn_cloudwatch_log_group   = "/AWSVPN"
vpn_cloudwatch_log_stream  = "VPNAccess"

# VPN login banner
vpn_login_banner_enabled = true
vpn_login_banner_text    = "Authorized Access Only"

# Additional CIDR blocks to authorize for VPN access
vpn_additional_authorized_cidrs = []

# ========================================
# OPTIONAL: Meilisearch Configuration
# ========================================

# Enable Meilisearch search engine
enable_meilisearch = true

# ========================================
# OPTIONAL: Email (SES) Configuration
# ========================================

# Enable AWS SES for sending emails
enable_ses = true

# Test email addresses (required when SES is in sandbox mode)
ses_test_emails = []

# ========================================
# OPTIONAL: Nightwatch Configuration
# ========================================

# Enable Laravel Nightwatch for browser automation and end-to-end testing
# Set to true to enable Nightwatch service
enable_nightwatch = false

# ========================================
# OPTIONAL: Monitoring Configuration
# ========================================

# Enable CloudTrail for API audit logging
enable_cloudtrail = true

# CloudWatch log retention in days
log_retention_days = 7 # Production: 30+

# Email addresses for health check alerts
healthcheck_alarm_emails = []

# Enable ALB access logs (useful for WAF triage and debugging)
enable_alb_access_logs = false

# ========================================
# OPTIONAL: Error Tracking (Sentry)
# ========================================

# Sentry DSN for error tracking (leave empty to disable)
sentry_dsn = ""

# ========================================
# OPTIONAL: Additional Environment Variables
# ========================================
# Add custom static environment variables here without creating new Terraform variables.
# These will be merged with the dynamic ones computed by the infrastructure.

additional_environment_variables = [
  # Laravel Configuration
  { name = "APP_DEBUG", value = "false" },
  { name = "DEBUGBAR_ENABLED", value = "false" },

  # Cache & Session
  { name = "CACHE_STORE", value = "redis" },
  { name = "SESSION_DRIVER", value = "redis" },
  { name = "SESSION_LIFETIME", value = "120" },
  { name = "SESSION_ENCRYPT", value = "false" },
  { name = "SESSION_PATH", value = "/" },
  { name = "SESSION_DOMAIN", value = "" },
  { name = "SESSION_SECURE_COOKIE", value = "true" },
  { name = "SESSION_SAME_SITE", value = "strict" },
  { name = "REDIS_CLIENT", value = "phpredis" },

  # Queue
  { name = "QUEUE_CONNECTION", value = "sqs" },
  { name = "QUEUE_FAILED_DRIVER", value = "database-uuids" },

  # Logging
  { name = "LOG_CHANNEL", value = "stack" },

  # Database
  { name = "DB_CONNECTION", value = "mysql" },
  { name = "DB_PORT", value = "3306" },

  # AWS/S3
  { name = "AWS_USE_PATH_STYLE_ENDPOINT", value = "false" },

  # Mail
  { name = "MAIL_MAILER", value = "ses" },

  # Storage/Logging
  { name = "FILESYSTEM_DISK", value = "s3" },
  { name = "FILAMENT_FILESYSTEM_DISK", value = "s3" },
  { name = "LOG_STACK", value = "daily,sentry" },

  # Monitoring
  { name = "PULSE_ENABLED", value = "true" },

  # Add your custom environment variables here:
  # { name = "CUSTOM_FEATURE_FLAG", value = "enabled" },
]

# ========================================
# OPTIONAL: Resource Tagging
# ========================================

# Cost center for resource tagging and cost allocation
cost_center = "Engineering"

# KMS key deletion window in days (7-30)
kms_deletion_window = 7

# ========================================
# OPTIONAL: DNS Configuration
# ========================================

# DMARC TXT record for email authentication (only set for production)
# Example: "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
dmarc_record = ""

# ========================================
# OPTIONAL: Compliance and Auditing
# ========================================
# Configure AWS security and compliance services for healthcare applications.
# Services marked as "production only" will only be created when environment = "production"

# AWS Config - Tracks resource configuration changes
# Environment-specific (created in all environments)
enable_aws_config  = true # Track all resource configuration changes
enable_hipaa_rules = true # Enable HIPAA-specific compliance rules

# AWS Security Hub - Centralized security dashboard
# Environment-specific (created in all environments)
enable_security_hub              = true  # Centralized security/compliance dashboard
enable_cis_standard              = true  # CIS AWS Foundations Benchmark
enable_aws_foundational_standard = true  # AWS Foundational Security Best Practices
enable_pci_dss_standard          = false # Enable if handling payment cards

# Email notifications for critical/high Security Hub findings
security_hub_notification_emails = []

# AWS GuardDuty - Threat detection
# Environment-specific (created in all environments)
enable_guardduty            = true              # Detect threats and suspicious activity
guardduty_finding_frequency = "FIFTEEN_MINUTES" # FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS

# Email notifications for GuardDuty threats
guardduty_notification_emails = []

# AWS Macie - PHI/PII Detection in S3
# PRODUCTION ONLY (only created when environment = "production")
enable_macie            = false      # Automatically scans S3 for PHI/PII (production only)
macie_finding_frequency = "ONE_HOUR" # FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS

# IAM Access Analyzer - External access detection
# PRODUCTION ONLY (only created when environment = "production")
enable_access_analyzer = false # Identifies resources shared with external entities (production only)

# AWS Backup Audit Manager - Backup compliance auditing
# PRODUCTION ONLY (only created when environment = "production")
enable_backup_audit_manager = false # Audits backup compliance (production only)
enable_hipaa_framework      = true  # Enable HIPAA backup compliance framework

# VPC Flow Logs - Network traffic logging
# Environment-specific (created in all environments)
# REQUIRED for HIPAA compliance
enable_vpc_flow_logs     = true  # Required for HIPAA
flow_logs_retention_days = 90    # Minimum 90 days recommended
flow_logs_traffic_type   = "ALL" # Log all traffic (ACCEPT, REJECT, ALL)
