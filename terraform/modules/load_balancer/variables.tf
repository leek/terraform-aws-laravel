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

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "alb_logs_bucket_name" {
  description = "ALB logs S3 bucket name"
  type        = string
}

variable "enable_access_logs" {
  description = "Enable ALB access logging"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the load balancer"
  type        = bool
  default     = false
}

variable "drop_invalid_header_fields" {
  description = "Enable dropping of invalid HTTP header fields"
  type        = bool
  default     = true
}

variable "blocked_uri_patterns" {
  description = "List of URI patterns to block at the WAF level (e.g., ['/login/login.html', '/admin.php', '/.env'])"
  type        = list(string)
  default     = []
}
