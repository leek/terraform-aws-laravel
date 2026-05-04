# ========================================
# ElastiCache Redis Replication Group
# ========================================

resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "${var.app_name}-${var.environment}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-redis-params"
  })
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.app_name}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnets

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-redis-subnet-group"
  })
}

# ElastiCache AUTH token rules: 16-128 printable ASCII chars. The only
# permitted special characters are: ! & # $ ^ < > -
resource "random_password" "redis_auth" {
  length           = 48
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.app_name}-${var.environment}-redis"
  description          = "${var.app_name} ${var.environment} Redis replication group"

  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  num_cache_clusters         = var.redis_num_cache_clusters
  automatic_failover_enabled = var.redis_num_cache_clusters > 1
  multi_az_enabled           = var.redis_num_cache_clusters > 1

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_security_group_id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result
  auth_token_update_strategy = "ROTATE"

  apply_immediately = var.apply_immediately

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-redis"
  })
}
