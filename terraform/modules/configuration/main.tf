# ========================================
# SSM Parameters
# ========================================

resource "aws_ssm_parameter" "app_key" {
  name      = "/${var.app_name}/${var.environment}/APP_KEY"
  type      = "SecureString"
  value     = var.app_key
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

resource "aws_ssm_parameter" "db_host" {
  name      = "/${var.app_name}/${var.environment}/DB_HOST"
  type      = "SecureString"
  value     = var.rds_endpoint
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

resource "aws_ssm_parameter" "db_database" {
  name      = "/${var.app_name}/${var.environment}/DB_DATABASE"
  type      = "SecureString"
  value     = var.rds_database_name
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

resource "aws_ssm_parameter" "db_username" {
  name      = "/${var.app_name}/${var.environment}/DB_USERNAME"
  type      = "SecureString"
  value     = var.app_db_username
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/${var.app_name}/${var.environment}/DB_PASSWORD"
  type      = "SecureString"
  value     = var.app_db_password
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

resource "aws_ssm_parameter" "sentry_dsn" {
  name      = "/${var.app_name}/${var.environment}/SENTRY_LARAVEL_DSN"
  type      = "SecureString"
  value     = var.sentry_dsn
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

# AWS IAM Credentials (secrets only - bucket/region are plain env vars in compute module)
resource "aws_ssm_parameter" "aws_access_key_id" {
  name      = "/${var.app_name}/${var.environment}/AWS_ACCESS_KEY_ID"
  type      = "SecureString"
  value     = var.aws_access_key_id
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

resource "aws_ssm_parameter" "aws_secret_access_key" {
  name      = "/${var.app_name}/${var.environment}/AWS_SECRET_ACCESS_KEY"
  type      = "SecureString"
  value     = var.aws_secret_access_key
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

# Read Replica Configuration (for Laravel database reads)
# Falls back to primary host if no replica exists
resource "aws_ssm_parameter" "db_read_host" {
  name      = "/${var.app_name}/${var.environment}/DB_READ_HOST"
  type      = "SecureString"
  value     = var.rds_read_replica_endpoint != "" ? var.rds_read_replica_endpoint : var.rds_endpoint
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}

# Nightwatch Token (optional)
resource "aws_ssm_parameter" "nightwatch_token" {
  count     = var.nightwatch_token != "" ? 1 : 0
  name      = "/${var.app_name}/${var.environment}/NIGHTWATCH_TOKEN"
  type      = "SecureString"
  value     = var.nightwatch_token
  key_id    = var.parameter_store_kms_key_id
  overwrite = true

  tags = var.common_tags
}
