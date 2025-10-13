# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb_security_group.security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs_security_group.security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.rds_security_group.security_group_id
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = module.redis_security_group.security_group_id
}

output "vpn_security_group_id" {
  description = "ID of the VPN security group"
  value       = module.vpn_security_group.security_group_id
}