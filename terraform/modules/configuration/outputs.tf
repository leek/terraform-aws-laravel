output "database_connection_info" {
  description = "Database connection information"
  value = {
    host       = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_HOST"
    database   = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_DATABASE"
    username   = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_USERNAME"
    password   = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_PASSWORD"
    reporting_password = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_REPORTING_PASSWORD"
    port       = "3306"
    connection = "Use AWS Session Manager to connect to ECS container, then connect to RDS from within the container"
  }
}

output "redis_connection_info" {
  description = "Redis connection information"
  value = {
    host       = "Available in Parameter Store: /${var.app_name}/${var.environment}/REDIS_HOST"
    port       = "Available in Parameter Store: /${var.app_name}/${var.environment}/REDIS_PORT"
    auth_token = "No authentication required (single-node cluster)"
    connection = "Use AWS Session Manager to connect to ECS container, then connect to Redis from within the container"
  }
}

