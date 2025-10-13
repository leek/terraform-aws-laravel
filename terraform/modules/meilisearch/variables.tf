variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name"
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

variable "ecs_cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "meilisearch_master_key" {
  description = "Meilisearch master key for authentication"
  type        = string
  sensitive   = true
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}