
# ========================================
# Database Engine Configuration
# ========================================

locals {
  # Determine if this is an Aurora deployment
  is_aurora = startswith(var.db_engine, "aurora-")
  
  # Map engine types to their configuration
  engine_config = {
    mysql = {
      engine               = "mysql"
      engine_version       = var.db_engine_version != "" ? var.db_engine_version : "8.0.43"
      major_engine_version = "8.0"
      family               = "mysql8.0"
      port                 = 3306
    }
    mariadb = {
      engine               = "mariadb"
      engine_version       = var.db_engine_version != "" ? var.db_engine_version : "10.11.9"
      major_engine_version = "10.11"
      family               = "mariadb10.11"
      port                 = 3306
    }
    postgres = {
      engine               = "postgres"
      engine_version       = var.db_engine_version != "" ? var.db_engine_version : "16.4"
      major_engine_version = "16"
      family               = "postgres16"
      port                 = 5432
    }
    aurora-mysql = {
      engine               = "aurora-mysql"
      engine_version       = var.db_engine_version != "" ? var.db_engine_version : "8.0.mysql_aurora.3.07.1"
      major_engine_version = "8.0"
      family               = "aurora-mysql8.0"
      port                 = 3306
    }
    aurora-postgresql = {
      engine               = "aurora-postgresql"
      engine_version       = var.db_engine_version != "" ? var.db_engine_version : "16.4"
      major_engine_version = "16"
      family               = "aurora-postgresql16"
      port                 = 5432
    }
  }
  
  # Get current engine config
  current_engine = local.engine_config[var.db_engine]
  
  # Determine instance class for Aurora vs RDS
  # Aurora Serverless v2 uses db.serverless, otherwise use provided instance class
  effective_instance_class = local.is_aurora && var.aurora_enable_serverlessv2 ? "db.serverless" : var.db_instance_class
}

# ========================================
# RDS Database (MySQL, MariaDB, PostgreSQL)
# ========================================

# Generate random password for RDS master user
resource "random_password" "rds_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store master password in Secrets Manager
resource "aws_secretsmanager_secret" "rds_master_password" {
  name        = "${var.app_name}-${var.environment}-rds-master-password"
  description = "Master password for RDS MySQL database"
  kms_key_id  = var.rds_kms_key_arn

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "rds_master_password" {
  secret_id = aws_secretsmanager_secret.rds_master_password.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.rds_master.result
  })
}

module "rds" {
  count   = local.is_aurora ? 0 : 1
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.app_name}-${var.environment}-db"

  engine                = local.current_engine.engine
  engine_version        = local.current_engine.engine_version
  major_engine_version  = local.current_engine.major_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage

  db_name  = "${var.app_name}_${var.environment}"
  username = "admin"
  password = random_password.rds_master.result

  # Explicitly disable managed master password to support read replicas
  manage_master_user_password = false

  apply_immediately = true

  vpc_security_group_ids = [var.rds_security_group_id]

  # Subnets
  create_db_subnet_group = true
  subnet_ids             = var.private_subnets

  # High Availability
  multi_az = var.multi_az

  # Parameter and option groups
  family                    = local.current_engine.family
  create_db_parameter_group = true
  create_db_option_group    = var.db_engine != "postgres" # PostgreSQL doesn't support option groups

  # Backup
  backup_retention_period = var.environment == "production" ? 30 : 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.rds_kms_key_arn

  # Monitoring
  monitoring_interval    = 60
  monitoring_role_name   = "${var.app_name}-${var.environment}-rds-monitoring-role"
  create_monitoring_role = true

  # Performance Insights
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Other settings
  deletion_protection = var.enable_deletion_protection

  skip_final_snapshot              = var.environment == "production" ? false : true
  final_snapshot_identifier_prefix = "${var.app_name}-${var.environment}-final-snapshot"

  # Port configuration
  port = local.current_engine.port

  tags = var.common_tags
}

# ========================================
# Read Replica (optional, RDS only)
# ========================================

module "rds_read_replica" {
  count   = !local.is_aurora && var.create_read_replica ? 1 : 0
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.app_name}-${var.environment}-db-replica"

  # Replica-specific settings
  replicate_source_db = module.rds[0].db_instance_identifier

  engine               = local.current_engine.engine
  engine_version       = local.current_engine.engine_version
  major_engine_version = local.current_engine.major_engine_version
  instance_class       = var.read_replica_instance_class != "" ? var.read_replica_instance_class : var.db_instance_class

  # Storage - inherit autoscaling settings from primary
  max_allocated_storage = var.db_max_allocated_storage

  # High Availability - match primary setting
  multi_az = var.multi_az

  # Parameter and option groups
  family                    = local.current_engine.family
  create_db_parameter_group = true
  create_db_option_group    = var.db_engine != "postgres" # PostgreSQL doesn't support option groups

  # Disable managed master password (not supported for replicas)
  manage_master_user_password = false

  # Maintenance window - must not overlap with primary
  maintenance_window = "Sun:05:30-Sun:06:30"

  # Read replicas inherit most settings from the source
  vpc_security_group_ids = [var.rds_security_group_id]

  # Monitoring
  monitoring_interval    = 60
  monitoring_role_name   = "${var.app_name}-${var.environment}-rds-replica-monitoring-role"
  create_monitoring_role = true

  # Performance Insights - match primary setting
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Other settings - match primary deletion protection
  deletion_protection = var.enable_deletion_protection
  apply_immediately   = true

  skip_final_snapshot              = var.environment == "production" ? false : true
  final_snapshot_identifier_prefix = "${var.app_name}-${var.environment}-read-final-snapshot"

  # Read replicas don't create subnet groups
  create_db_subnet_group = false

  # Port configuration
  port = local.current_engine.port

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-db-replica"
    Role = "ReadReplica"
  })
}

# ========================================
# Aurora Cluster (MySQL or PostgreSQL)
# ========================================

module "aurora" {
  count   = local.is_aurora ? 1 : 0
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.0"

  name           = "${var.app_name}-${var.environment}-aurora"
  engine         = local.current_engine.engine
  engine_version = local.current_engine.engine_version
  instance_class = local.effective_instance_class

  instances = var.aurora_enable_serverlessv2 ? {
    serverless = {
      instance_class = "db.serverless"
    }
  } : { for i in range(var.aurora_instance_count) : "instance-${i + 1}" => {
    instance_class = var.db_instance_class
  } }

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration = var.aurora_enable_serverlessv2 ? {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  } : null

  vpc_id               = var.vpc_id
  db_subnet_group_name = aws_db_subnet_group.aurora[0].name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = [data.aws_vpc.selected[0].cidr_block]
    }
  }

  # Use security group from networking module
  create_security_group = false
  vpc_security_group_ids = [var.rds_security_group_id]

  storage_encrypted = true
  kms_key_id        = var.rds_kms_key_arn

  # Database configuration
  database_name   = "${var.app_name}_${var.environment}"
  master_username = "admin"
  master_password = random_password.rds_master.result

  # Don't use managed password for consistency with RDS
  manage_master_user_password = false

  # Backup configuration
  backup_retention_period      = var.environment == "production" ? 30 : 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Monitoring
  enabled_cloudwatch_logs_exports = var.db_engine == "aurora-mysql" ? ["audit", "error", "general", "slowquery"] : ["postgresql"]
  monitoring_interval             = 60
  create_monitoring_role          = true

  # Performance Insights
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Deletion protection
  deletion_protection = var.enable_deletion_protection
  skip_final_snapshot = var.environment == "production" ? false : true

  # Multi-AZ for high availability
  availability_zones = var.multi_az ? null : [data.aws_availability_zones.available.names[0]]

  apply_immediately = true

  tags = var.common_tags
}

# Subnet group for Aurora (needed because we're not using the module's subnet creation)
resource "aws_db_subnet_group" "aurora" {
  count      = local.is_aurora ? 1 : 0
  name       = "${var.app_name}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.private_subnets

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-aurora-subnet-group"
  })
}

# Data sources for Aurora
data "aws_vpc" "selected" {
  count = local.is_aurora ? 1 : 0
  id    = var.vpc_id
}

data "aws_availability_zones" "available" {
  count = local.is_aurora ? 1 : 0
  state = "available"
}
