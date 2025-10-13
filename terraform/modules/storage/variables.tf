variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for CORS configuration"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}


variable "s3_filesystem_kms_key_arn" {
  description = "ARN of the KMS key for S3 filesystem encryption"
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