variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "app_key" {
  description = "Laravel application key (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "parameter_store_kms_key_id" {
  description = "KMS key ID for Parameter Store encryption"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS endpoint"
  type        = string
}

variable "rds_database_name" {
  description = "RDS database name"
  type        = string
}

variable "db_connection" {
  description = "Laravel database connection driver (mysql or pgsql)"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "rds_username" {
  description = "RDS master username (admin)"
  type        = string
}

variable "app_db_username" {
  description = "Application database username"
  type        = string
}

variable "app_db_password" {
  description = "Application database password"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS access key ID for Laravel application"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key for Laravel application"
  type        = string
  sensitive   = true
}

variable "rds_read_replica_endpoint" {
  description = "RDS read replica endpoint (optional)"
  type        = string
  default     = ""
}

variable "redis_auth_token" {
  description = "Redis AUTH token to store as REDIS_PASSWORD"
  type        = string
  sensitive   = true
}

variable "additional_secret_environment_variables" {
  description = "Additional secret env vars to store as SSM SecureString parameters under /{app_name}/{environment}/{NAME}"
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
