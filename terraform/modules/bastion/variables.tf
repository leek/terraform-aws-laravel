variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where bastion will be created"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for bastion host"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.nano"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to bastion"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified for SSH access. Never use 0.0.0.0/0 in production."
  }
}

variable "install_mysql_client" {
  description = "Install MySQL client on bastion"
  type        = bool
  default     = true
}

variable "install_redis_client" {
  description = "Install Redis client on bastion"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "rds_endpoint" {
  description = "RDS endpoint for MySQL database"
  type        = string
  default     = ""
}

variable "rds_master_username" {
  description = "RDS master username"
  type        = string
  default     = ""
}

variable "rds_master_password_secret_arn" {
  description = "ARN of the secret containing RDS master password"
  type        = string
  default     = ""
}

variable "rds_database_name" {
  description = "RDS database name"
  type        = string
  default     = ""
}

variable "app_db_username" {
  description = "Application database username to create"
  type        = string
  default     = ""
}

variable "app_db_password" {
  description = "Application database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_reporting_password" {
  description = "Read-only reporting database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "rds_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt RDS secrets"
  type        = string
  default     = ""
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for the bastion instance"
  type        = bool
  default     = true
}

variable "ebs_optimized" {
  description = "Enable EBS optimization for the bastion instance (not supported for t3.nano by default)"
  type        = bool
  default     = false
}

variable "root_block_device_encrypted" {
  description = "Enable encryption for the root block device"
  type        = bool
  default     = true
}

variable "root_block_device_kms_key_id" {
  description = "KMS key ID to use for root block device encryption"
  type        = string
  default     = ""
}
