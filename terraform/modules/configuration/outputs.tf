output "database_connection_info" {
  description = "Database connection information"
  value = {
    host       = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_HOST"
    database   = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_DATABASE"
    username   = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_USERNAME"
    password   = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_PASSWORD"
    driver     = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_CONNECTION"
    port       = "Available in Parameter Store: /${var.app_name}/${var.environment}/DB_PORT"
    connection = "Use AWS Session Manager to connect to ECS container, then connect to RDS from within the container"
  }
}

output "redis_connection_info" {
  description = "Redis connection information"
  value = {
    host       = "Available in Parameter Store: /${var.app_name}/${var.environment}/REDIS_HOST"
    port       = "Available in Parameter Store: /${var.app_name}/${var.environment}/REDIS_PORT"
    auth_token = "Available in Parameter Store: /${var.app_name}/${var.environment}/REDIS_PASSWORD"
    connection = "Use AWS Session Manager to connect to ECS container, then connect to Redis from within the container"
  }
}
