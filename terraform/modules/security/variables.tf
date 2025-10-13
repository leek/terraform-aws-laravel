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

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository"
  type        = string
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

variable "create_github_oidc_provider" {
  description = "Create GitHub OIDC provider (should only be true for one environment to avoid conflicts)"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "caller_identity_account_id" {
  description = "AWS account ID"
  type        = string
}