# ========================================
# AWS Config (Account-Level)
# ========================================
# Note: AWS Config Recorder is account-level (1 per region per account)
# Only created in production environment to avoid conflicts

# IAM role for AWS Config
resource "aws_iam_role" "config" {
  count = var.enable_aws_config && var.environment == "production" ? 1 : 0

  name_prefix = "${var.app_name}-config-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

# Attach AWS managed policy for Config
resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_aws_config && var.environment == "production" ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Additional policy for S3 access
resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_aws_config && var.environment == "production" ? 1 : 0

  name = "${var.app_name}-config-s3-policy"
  role = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.config_bucket_name}",
          "arn:aws:s3:::${var.config_bucket_name}/*"
        ]
      }
    ]
  })
}

# Config recorder
resource "aws_config_configuration_recorder" "main" {
  count = var.enable_aws_config && var.environment == "production" ? 1 : 0

  name     = "${var.app_name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Config delivery channel
resource "aws_config_delivery_channel" "main" {
  count = var.enable_aws_config && var.environment == "production" ? 1 : 0

  name           = "${var.app_name}-config-delivery"
  s3_bucket_name = var.config_bucket_name
  sns_topic_arn  = var.config_sns_topic_arn != "" ? var.config_sns_topic_arn : null

  depends_on = [aws_config_configuration_recorder.main]
}

# Start the recorder
resource "aws_config_configuration_recorder_status" "main" {
  count = var.enable_aws_config && var.environment == "production" ? 1 : 0

  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# ========================================
# AWS Config Rules - HIPAA Compliance
# ========================================

# Encryption at rest
resource "aws_config_config_rule" "encrypted_volumes" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "rds_storage_encrypted" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-rds-storage-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_server_side_encryption" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-s3-bucket-encryption"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Access logging
resource "aws_config_config_rule" "s3_bucket_logging_enabled" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-s3-bucket-logging"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LOGGING_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Multi-AZ and backups
resource "aws_config_config_rule" "rds_multi_az_support" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-rds-multi-az"

  source {
    owner             = "AWS"
    source_identifier = "RDS_MULTI_AZ_SUPPORT"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "db_backup_enabled" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-db-backup-enabled"

  source {
    owner             = "AWS"
    source_identifier = "DB_INSTANCE_BACKUP_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Access control
resource "aws_config_config_rule" "iam_password_policy" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-iam-password-policy"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireSymbols             = "true"
    RequireNumbers             = "true"
    MinimumPasswordLength      = "14"
    PasswordReusePrevention    = "24"
    MaxPasswordAge             = "90"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "root_account_mfa_enabled" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-root-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# VPC security
resource "aws_config_config_rule" "vpc_flow_logs_enabled" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-vpc-flow-logs-enabled"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "vpc_sg_open_only_to_authorized_ports" {
  count = var.enable_aws_config && var.enable_hipaa_rules ? 1 : 0

  name = "${var.app_name}-${var.environment}-vpc-sg-authorized-ports"

  source {
    owner             = "AWS"
    source_identifier = "VPC_SG_OPEN_ONLY_TO_AUTHORIZED_PORTS"
  }

  input_parameters = jsonencode({
    authorizedTcpPorts = join(",", var.authorized_tcp_ports)
  })

  depends_on = [aws_config_configuration_recorder.main]
}