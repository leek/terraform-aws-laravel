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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "RDS security group ID"
  type        = string
}

variable "rds_kms_key_arn" {
  description = "ARN of the KMS key for RDS encryption"
  type        = string
}

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
  description = "Maximum storage for autoscaling (GB). Set to 0 to disable autoscaling."
  type        = number
  default     = 0
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights (requires instance class that supports it)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for RDS instance"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "create_read_replica" {
  description = "Create a read replica for the RDS instance"
  type        = bool
  default     = false
}

variable "read_replica_instance_class" {
  description = "Instance class for read replica (defaults to primary instance class if not specified)"
  type        = string
  default     = ""
}

variable "db_engine" {
  description = "Database engine type: mysql, mariadb, postgres, aurora-mysql, or aurora-postgresql"
  type        = string
  default     = "mysql"
  validation {
    condition     = contains(["mysql", "mariadb", "postgres", "aurora-mysql", "aurora-postgresql"], var.db_engine)
    error_message = "db_engine must be one of: mysql, mariadb, postgres, aurora-mysql, or aurora-postgresql"
  }
}

variable "db_engine_version" {
  description = "Database engine version. Leave empty to use default for selected engine."
  type        = string
  default     = ""
}

variable "aurora_enable_serverlessv2" {
  description = "Enable Aurora Serverless v2 scaling (only for Aurora engines)"
  type        = bool
  default     = false
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora Capacity Units (ACUs) for Serverless v2. 0.5 to 128 in 0.5 increments."
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora Capacity Units (ACUs) for Serverless v2. 0.5 to 128 in 0.5 increments."
  type        = number
  default     = 1.0
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances to create (only for non-serverless Aurora)"
  type        = number
  default     = 1
}
