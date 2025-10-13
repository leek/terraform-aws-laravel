# ========================================
# ElastiCache Redis Cluster
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

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.app_name}-${var.environment}-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [var.redis_security_group_id]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-redis"
  })
}