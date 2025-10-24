variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "redis_security_group_id" {
  description = "Security group ID for Redis"
  type        = string
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.small"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain Redis snapshots (0 to disable backups)"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Daily time range for Redis snapshots (UTC)"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly time range for Redis maintenance (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00"
}
