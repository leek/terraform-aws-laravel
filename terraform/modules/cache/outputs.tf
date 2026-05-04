output "redis_endpoint" {
  description = "Primary endpoint of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Port of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_auth_token" {
  description = "AUTH token for the Redis replication group"
  value       = random_password.redis_auth.result
  sensitive   = true
}
