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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "db_port" {
  description = "Database port for security group rules"
  type        = number
  default     = 3306
}