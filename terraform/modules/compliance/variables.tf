# ========================================
# Compliance Module Variables
# ========================================

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment (development, staging, production)"
  type        = string
  validation {
    condition     = contains(["development", "staging", "uat", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, uat, production."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

variable "caller_identity_account_id" {
  description = "AWS account ID"
  type        = string
}

# ========================================
# VPC Configuration
# ========================================

variable "vpc_id" {
  description = "VPC ID for flow logs"
  type        = string
}

variable "vpc_flow_logs_bucket_arn" {
  description = "S3 bucket ARN for VPC flow logs"
  type        = string
}

# ========================================
# AWS Config
# ========================================

variable "enable_aws_config" {
  description = "Enable AWS Config for compliance tracking"
  type        = bool
  default     = true
}

variable "config_bucket_name" {
  description = "S3 bucket name for AWS Config"
  type        = string
}

variable "config_sns_topic_arn" {
  description = "SNS topic ARN for AWS Config notifications"
  type        = string
  default     = ""
}

variable "enable_hipaa_rules" {
  description = "Enable HIPAA-specific AWS Config rules"
  type        = bool
  default     = true
}

variable "authorized_tcp_ports" {
  type        = list(number)
  default     = [22, 80, 443]
  description = "TCP ports allowed to be open to 0.0.0.0/0."
}

# ========================================
# AWS Security Hub
# ========================================

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_cis_standard" {
  description = "Enable CIS AWS Foundations Benchmark"
  type        = bool
  default     = true
}

variable "enable_pci_dss_standard" {
  description = "Enable PCI DSS standard"
  type        = bool
  default     = false
}

variable "enable_aws_foundational_standard" {
  description = "Enable AWS Foundational Security Best Practices"
  type        = bool
  default     = true
}

variable "security_hub_notification_emails" {
  description = "Email addresses to notify for Security Hub findings"
  type        = list(string)
  default     = []
}

variable "sns_kms_key_id" {
  type        = string
  default     = null
  description = "CMK ARN or alias for SNS topics; defaults to alias/aws/sns."
}

# ========================================
# AWS GuardDuty
# ========================================

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

# ========================================
# AWS Macie (Production Only)
# ========================================

variable "enable_macie" {
  description = "Enable AWS Macie for PHI detection (production only)"
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

variable "macie_s3_buckets" {
  description = "List of S3 bucket names to scan with Macie"
  type        = list(string)
  default     = []
}

variable "macie_findings_bucket_name" {
  description = "S3 bucket name for Macie findings export"
  type        = string
  default     = ""
}

variable "s3_filesystem_kms_key_arn" {
  description = "KMS key ARN for S3 filesystem encryption (used by Macie)"
  type        = string
  default     = ""
}

# ========================================
# IAM Access Analyzer (Production Only)
# ========================================

variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer (production only)"
  type        = bool
  default     = false
}

# ========================================
# AWS Backup Audit Manager (Production Only)
# ========================================

variable "enable_backup_audit_manager" {
  description = "Enable AWS Backup Audit Manager (production only)"
  type        = bool
  default     = false
}

variable "backup_vault_arn" {
  description = "ARN of the backup vault to audit"
  type        = string
  default     = ""
}

variable "backup_kms_key_arn" {
  description = "KMS key ARN for AWS Backup encryption"
  type        = string
  default     = ""
}

variable "enable_hipaa_framework" {
  description = "Enable HIPAA backup compliance framework"
  type        = bool
  default     = true
}

# ========================================
# VPC Flow Logs
# ========================================

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
