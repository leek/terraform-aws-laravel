# RDS Outputs
output "rds_endpoint" {
  description = "Endpoint of the database instance (hostname only)"
  value       = local.is_aurora ? (length(module.aurora) > 0 ? split(":", module.aurora[0].cluster_endpoint)[0] : null) : (length(module.rds) > 0 ? split(":", module.rds[0].db_instance_endpoint)[0] : null)
}

output "rds_database_name" {
  description = "Name of the database"
  value       = local.is_aurora ? (length(module.aurora) > 0 ? module.aurora[0].cluster_database_name : null) : (length(module.rds) > 0 ? module.rds[0].db_instance_name : null)
}

output "rds_username" {
  description = "Username for the database"
  value       = local.is_aurora ? (length(module.aurora) > 0 ? module.aurora[0].cluster_master_username : null) : (length(module.rds) > 0 ? module.rds[0].db_instance_username : null)
}

output "rds_secret_arn" {
  description = "ARN of the secret for the database master user password"
  value       = aws_secretsmanager_secret.rds_master_password.arn
}

output "rds_instance_id" {
  description = "Database instance ID"
  value       = local.is_aurora ? (length(module.aurora) > 0 ? module.aurora[0].cluster_id : null) : (length(module.rds) > 0 ? module.rds[0].db_instance_identifier : null)
}

output "rds_read_replica_endpoint" {
  description = "Endpoint of the read replica (hostname only). For Aurora, returns the reader endpoint."
  value       = local.is_aurora ? (length(module.aurora) > 0 ? split(":", module.aurora[0].cluster_reader_endpoint)[0] : null) : (var.create_read_replica && !local.is_aurora ? split(":", module.rds_read_replica[0].db_instance_endpoint)[0] : null)
}

output "rds_read_replica_id" {
  description = "Read replica instance ID. For Aurora, returns the cluster ID."
  value       = local.is_aurora ? (length(module.aurora) > 0 ? module.aurora[0].cluster_id : null) : (var.create_read_replica && !local.is_aurora ? module.rds_read_replica[0].db_instance_identifier : null)
}

output "rds_port" {
  description = "Database port"
  value       = local.current_engine.port
}

output "db_engine" {
  description = "Database engine type"
  value       = var.db_engine
}

output "is_aurora" {
  description = "Whether this is an Aurora deployment"
  value       = local.is_aurora
}
