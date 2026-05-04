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
