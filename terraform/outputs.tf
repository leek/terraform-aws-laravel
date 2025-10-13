# ========================================
# Outputs (consolidated from modules)
# ========================================

# Application
output "application_url" {
  description = "URL of the application"
  value       = module.dns.application_url
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}

# Networking
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnets
}

# Security Groups
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.networking.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.networking.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.networking.rds_security_group_id
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = module.networking.redis_security_group_id
}

# Load Balancer
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.load_balancer.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.load_balancer.alb_dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = module.load_balancer.alb_zone_id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = module.load_balancer.waf_web_acl_arn
}

# Certificates
output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.certificates.certificate_arn
}

# Container Registry
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.container_registry.repository_url
}

# Compute
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.compute.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.compute.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.compute.service_name
}

output "ecs_session_manager_command" {
  description = "Command to connect to ECS container via Session Manager"
  value       = module.compute.ecs_session_manager_command
}

# Database
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.rds_endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.database.rds_database_name
}

output "rds_username" {
  description = "RDS master username"
  value       = module.database.rds_username
  sensitive   = true
}

output "rds_secret_arn" {
  description = "ARN of the RDS master user secret"
  value       = module.database.rds_secret_arn
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = module.database.rds_instance_id
}

output "rds_read_replica_endpoint" {
  description = "RDS read replica endpoint (if enabled)"
  value       = module.database.rds_read_replica_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.cache.redis_endpoint
  sensitive   = true
}

output "redis_port" {
  description = "Redis cluster port"
  value       = module.cache.redis_port
}

# Messaging
output "sqs_queue_url" {
  description = "URL of the main SQS queue"
  value       = module.messaging.queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the main SQS queue"
  value       = module.messaging.queue_arn
}

output "sqs_deadletter_queue_url" {
  description = "URL of the SQS dead letter queue"
  value       = module.messaging.deadletter_queue_url
}

output "sqs_deadletter_queue_arn" {
  description = "ARN of the SQS dead letter queue"
  value       = module.messaging.deadletter_queue_arn
}

# Storage
output "alb_logs_bucket_name" {
  description = "Name of the ALB logs bucket"
  value       = module.storage.alb_logs_bucket_name
}

output "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail bucket"
  value       = module.storage.cloudtrail_bucket_name
}

# Security
output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = module.security.ecs_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.security.ecs_task_role_arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = module.security.github_actions_role_arn
}

output "parameter_store_kms_key_id" {
  description = "KMS key ID for Parameter Store encryption"
  value       = module.security.parameter_store_kms_key_id
}

output "rds_kms_key_id" {
  description = "KMS key ID for RDS encryption"
  value       = module.security.rds_kms_key_id
}

# Monitoring
output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.monitoring.log_group_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = module.monitoring.cloudtrail_arn
}

# Configuration
output "database_connection_info" {
  description = "Database connection information"
  value       = module.configuration.database_connection_info
}

output "redis_connection_info" {
  description = "Redis connection information"
  value       = module.configuration.redis_connection_info
}

# Bastion (conditional outputs)
output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = var.enable_bastion ? module.bastion[0].public_ip : "Bastion disabled"
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion"
  value       = var.enable_bastion ? module.bastion[0].ssh_command : "Bastion disabled"
}

output "mysql_tunnel_command" {
  description = "MySQL tunnel command via bastion"
  value       = var.enable_bastion ? "ssh -i ~/.ssh/${var.ec2_key_name}.pem -L 3306:${module.database.rds_endpoint}:3306 ec2-user@${module.bastion[0].public_ip}" : "Bastion disabled - use VPN or direct access"
}

output "redis_tunnel_command" {
  description = "Redis tunnel command via bastion"
  value       = var.enable_bastion ? "ssh -i ~/.ssh/${var.ec2_key_name}.pem -L 6379:${module.cache.redis_endpoint}:6379 ec2-user@${module.bastion[0].public_ip}" : "Bastion disabled - use VPN or direct access"
}
