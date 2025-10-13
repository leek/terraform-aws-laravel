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

variable "cloudtrail_bucket_name" {
  description = "CloudTrail S3 bucket name"
  type        = string
}

variable "caller_identity_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "domain_name" {
  description = "Domain name for health check"
  type        = string
}

variable "healthcheck_alarm_emails" {
  description = "List of email addresses to notify for health check alarms"
  type        = list(string)
  default     = []
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for API audit logging"
  type        = bool
  default     = true
}