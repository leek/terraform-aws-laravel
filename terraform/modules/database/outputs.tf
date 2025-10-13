# RDS Outputs
output "rds_endpoint" {
  description = "Endpoint of the RDS instance (hostname only)"
  value       = split(":", module.rds.db_instance_endpoint)[0]
}

output "rds_database_name" {
  description = "Name of the RDS database"
  value       = module.rds.db_instance_name
}

output "rds_username" {
  description = "Username for the RDS database"
  value       = module.rds.db_instance_username
}

output "rds_secret_arn" {
  description = "ARN of the secret for the RDS database master user password"
  value       = aws_secretsmanager_secret.rds_master_password.arn
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.rds.db_instance_identifier
}

output "rds_read_replica_endpoint" {
  description = "Endpoint of the read replica (hostname only)"
  value       = var.create_read_replica ? split(":", module.rds_read_replica[0].db_instance_endpoint)[0] : null
}

output "rds_read_replica_id" {
  description = "Read replica instance ID"
  value       = var.create_read_replica ? module.rds_read_replica[0].db_instance_identifier : null
}
