
# ========================================
# RDS MySQL Database
# ========================================

# Generate random password for RDS master user
resource "random_password" "rds_master" {
  length  = 32
  special = true
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
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.app_name}-${var.environment}-db"

  engine               = "mysql"
  engine_version       = "8.0.40"
  major_engine_version = "8.0"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
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
  subnet_ids            = var.private_subnets

  # High Availability
  multi_az = var.multi_az

  # Parameter and option groups
  family                    = "mysql8.0"
  create_db_parameter_group = true
  create_db_option_group    = true

  # Backup
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Sun:04:00-Sun:05:00"

  # Encryption
  storage_encrypted   = true
  kms_key_id         = var.rds_kms_key_arn

  # Monitoring
  monitoring_interval = 60
  monitoring_role_name = "${var.app_name}-${var.environment}-rds-monitoring-role"
  create_monitoring_role = true

  # Performance Insights
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Other settings
  deletion_protection = var.enable_deletion_protection
  skip_final_snapshot = true

  tags = var.common_tags
}

# ========================================
# Read Replica (optional)
# ========================================

module "rds_read_replica" {
  count   = var.create_read_replica ? 1 : 0
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.app_name}-${var.environment}-db-replica"

  # Replica-specific settings
  replicate_source_db = module.rds.db_instance_identifier

  engine               = "mysql"
  engine_version       = "8.0.40"
  major_engine_version = "8.0"
  instance_class       = var.read_replica_instance_class != "" ? var.read_replica_instance_class : var.db_instance_class

  # Storage - inherit autoscaling settings from primary
  max_allocated_storage = var.db_max_allocated_storage

  # High Availability - match primary setting
  multi_az = var.multi_az

  # Parameter and option groups
  family                    = "mysql8.0"
  create_db_parameter_group = true
  create_db_option_group    = true

  # Disable managed master password (not supported for replicas)
  manage_master_user_password = false

  # Read replicas inherit most settings from the source
  vpc_security_group_ids = [var.rds_security_group_id]

  # Monitoring
  monitoring_interval = 60
  monitoring_role_name = "${var.app_name}-${var.environment}-rds-replica-monitoring-role"
  create_monitoring_role = true

  # Performance Insights - match primary setting
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Other settings - match primary deletion protection
  deletion_protection = var.enable_deletion_protection
  skip_final_snapshot = true
  apply_immediately = true

  # Read replicas don't create subnet groups
  create_db_subnet_group = false

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-db-replica"
    Role = "ReadReplica"
  })
}
