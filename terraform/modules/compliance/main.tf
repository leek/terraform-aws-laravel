# ========================================
# AWS Compliance and Auditing Module
# ========================================
#
# This module configures AWS security and compliance services for healthcare applications:
# - AWS Config: Tracks resource configurations and compliance rules
# - AWS Security Hub: Centralized security findings and compliance standards
# - AWS GuardDuty: Threat detection
# - AWS Macie: PHI/PII detection in S3 (production only)
# - IAM Access Analyzer: External access detection (production only)
# - AWS Backup Audit Manager: Backup compliance auditing (production only)
# - VPC Flow Logs: Network traffic logging (HIPAA requirement)
#

# ========================================
# VPC Flow Logs (Environment-Specific)
# ========================================

resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id               = var.vpc_id
  traffic_type         = var.flow_logs_traffic_type
  log_destination_type = "s3"
  log_destination      = var.vpc_flow_logs_bucket_arn

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.app_name}-${var.environment}-vpc-flow-logs"
    }
  )
}

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

# ========================================
# AWS Security Hub (Account-Level)
# ========================================
# Note: Security Hub is account-level
# Only created in production environment to avoid conflicts

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub && var.environment == "production" ? 1 : 0

  control_finding_generator = "SECURITY_CONTROL"
  enable_default_standards  = false
}

# CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis" {
  count = var.enable_security_hub && var.enable_cis_standard && var.environment == "production" ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

# AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "foundational" {
  count = var.enable_security_hub && var.enable_aws_foundational_standard && var.environment == "production" ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# PCI DSS
resource "aws_securityhub_standards_subscription" "pci_dss" {
  count = var.enable_security_hub && var.enable_pci_dss_standard && var.environment == "production" ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/pci-dss/v/3.2.1"

  depends_on = [aws_securityhub_account.main]
}

# SNS topic for Security Hub findings
resource "aws_sns_topic" "security_hub_findings" {
  count = var.enable_security_hub && length(var.security_hub_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  name              = "${var.app_name}-security-hub-findings"
  kms_master_key_id = coalesce(var.sns_kms_key_id, "alias/aws/sns")

  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "security_hub_email" {
  count = var.enable_security_hub && length(var.security_hub_notification_emails) > 0 && var.environment == "production" ? length(var.security_hub_notification_emails) : 0

  topic_arn = aws_sns_topic.security_hub_findings[0].arn
  protocol  = "email"
  endpoint  = var.security_hub_notification_emails[count.index]
}

# EventBridge rule for critical/high Security Hub findings
resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  count = var.enable_security_hub && length(var.security_hub_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  name        = "${var.app_name}-security-hub-findings"
  description = "Capture critical and high severity Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
      }
    }
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "security_hub_sns" {
  count = var.enable_security_hub && length(var.security_hub_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_hub_findings[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_hub_findings[0].arn
}

resource "aws_sns_topic_policy" "security_hub_findings" {
  count = var.enable_security_hub && length(var.security_hub_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  arn = aws_sns_topic.security_hub_findings[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "SNS:Publish"
      Resource = aws_sns_topic.security_hub_findings[0].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.security_hub_findings[0].arn
        }
      }
    }]
  })
}

# ========================================
# AWS GuardDuty (Account-Level)
# ========================================
# Note: GuardDuty detector is account-level
# Notifications only created in production environment

# Use existing GuardDuty detector if available
data "aws_guardduty_detector" "existing" {
  count = var.enable_guardduty && var.environment == "production" ? 1 : 0
}

# SNS topic for GuardDuty findings
resource "aws_sns_topic" "guardduty_findings" {
  count = var.enable_guardduty && length(var.guardduty_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  name              = "${var.app_name}-guardduty-findings"
  kms_master_key_id = coalesce(var.sns_kms_key_id, "alias/aws/sns")

  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "guardduty_email" {
  count = var.enable_guardduty && length(var.guardduty_notification_emails) > 0 && var.environment == "production" ? length(var.guardduty_notification_emails) : 0

  topic_arn = aws_sns_topic.guardduty_findings[0].arn
  protocol  = "email"
  endpoint  = var.guardduty_notification_emails[count.index]
}

# EventBridge rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = var.enable_guardduty && length(var.guardduty_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  name        = "${var.app_name}-guardduty-findings"
  description = "Capture medium to high severity GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        { numeric = [">=", 4] }
      ]
    }
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  count = var.enable_guardduty && length(var.guardduty_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_findings[0].arn
}

resource "aws_sns_topic_policy" "guardduty_findings" {
  count = var.enable_guardduty && length(var.guardduty_notification_emails) > 0 && var.environment == "production" ? 1 : 0

  arn = aws_sns_topic.guardduty_findings[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "SNS:Publish"
      Resource = aws_sns_topic.guardduty_findings[0].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.guardduty_findings[0].arn
        }
      }
    }]
  })
}

# ========================================
# AWS Macie (Production Only)
# ========================================

resource "aws_macie2_account" "main" {
  count = var.enable_macie && var.environment == "production" ? 1 : 0

  finding_publishing_frequency = var.macie_finding_frequency
  status                       = "ENABLED"
}

# Wait for Macie service-linked role to propagate
resource "time_sleep" "wait_for_macie_role" {
  count = var.enable_macie && var.environment == "production" ? 1 : 0

  create_duration = "2m"

  depends_on = [aws_macie2_account.main]
}

# Macie classification job for S3 buckets
resource "aws_macie2_classification_job" "s3_phi_scan" {
  count = var.enable_macie && var.environment == "production" && length(var.macie_s3_buckets) > 0 ? 1 : 0

  name        = "${var.app_name}-phi-detection"
  description = "Scan S3 buckets for PHI/PII data"
  job_type    = "SCHEDULED"

  schedule_frequency {
    daily_schedule = true
  }

  s3_job_definition {
    dynamic "bucket_definitions" {
      for_each = var.macie_s3_buckets
      content {
        account_id = var.caller_identity_account_id
        buckets    = [bucket_definitions.value]
      }
    }
  }

  tags = var.common_tags

  depends_on = [time_sleep.wait_for_macie_role]
}

# Macie classification export configuration
resource "aws_macie2_classification_export_configuration" "main" {
  count = var.enable_macie && var.environment == "production" && var.macie_findings_bucket_name != "" ? 1 : 0

  s3_destination {
    bucket_name = var.macie_findings_bucket_name
    key_prefix  = "sensitive-data-discovery/"
    kms_key_arn = var.s3_filesystem_kms_key_arn
  }

  depends_on = [time_sleep.wait_for_macie_role]
}

# ========================================
# IAM Access Analyzer (Production Only)
# ========================================

resource "aws_accessanalyzer_analyzer" "main" {
  count = var.enable_access_analyzer && var.environment == "production" ? 1 : 0

  analyzer_name = "${var.app_name}-access-analyzer"
  type          = "ACCOUNT"

  tags = var.common_tags
}

# ========================================
# AWS Backup (Production Only)
# ========================================

# IAM role for AWS Backup
resource "aws_iam_role" "backup" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name = "${var.app_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

# Attach AWS managed backup policies
resource "aws_iam_role_policy_attachment" "backup_service" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Backup vault
resource "aws_backup_vault" "main" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name        = "${var.app_name}-backup-vault"
  kms_key_arn = var.backup_kms_key_arn

  tags = var.common_tags
}

# Backup plan with daily backups and 35-day retention
resource "aws_backup_plan" "daily" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name = "${var.app_name}-daily-backup-plan"

  rule {
    rule_name         = "daily_backup_35day_retention"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = "cron(0 5 * * ? *)" # Daily at 5 AM UTC
    start_window      = 60                  # Start within 1 hour
    completion_window = 120                 # Complete within 2 hours

    lifecycle {
      delete_after = 35 # HIPAA requirement: 35 days minimum
    }

    recovery_point_tags = merge(var.common_tags, {
      BackupPlan = "daily"
    })
  }

  tags = var.common_tags
}

# Backup selection for RDS databases (production only)
resource "aws_backup_selection" "rds" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name         = "${var.app_name}-rds-backup-selection"
  iam_role_arn = aws_iam_role.backup[0].arn
  plan_id      = aws_backup_plan.daily[0].id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = "production"
  }

  resources = ["arn:aws:rds:*:${var.caller_identity_account_id}:db:*"]
}

# Backup selection for EBS volumes (production only)
resource "aws_backup_selection" "ebs" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name         = "${var.app_name}-ebs-backup-selection"
  iam_role_arn = aws_iam_role.backup[0].arn
  plan_id      = aws_backup_plan.daily[0].id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = "production"
  }

  resources = ["arn:aws:ec2:*:${var.caller_identity_account_id}:volume/*"]
}

# IAM role for restore testing
resource "aws_iam_role" "restore_testing" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name = "${var.app_name}-restore-testing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

# Attach restore testing policy
resource "aws_iam_role_policy_attachment" "restore_testing" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  role       = aws_iam_role.restore_testing[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Additional permissions for restore testing
resource "aws_iam_role_policy" "restore_testing_additional" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name = "${var.app_name}-restore-testing-additional-policy"
  role = aws_iam_role.restore_testing[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:DescribeVolumes",
          "ec2:CreateTags",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource",
          "rds:RestoreDBInstanceFromDBSnapshot"
        ]
        Resource = "*"
      }
    ]
  })
}

# Restore testing plan - Weekly on Sundays
resource "aws_backup_restore_testing_plan" "weekly" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name = "${var.app_name}_weekly_restore_test"

  schedule_expression = "cron(0 6 ? * SUN *)" # Every Sunday at 6 AM UTC

  recovery_point_selection {
    algorithm = "LATEST_WITHIN_WINDOW"

    include_vaults = [aws_backup_vault.main[0].arn]

    recovery_point_types = ["CONTINUOUS", "SNAPSHOT"]

    selection_window_days = 7 # Test recovery points from the last 7 days
  }

  tags = var.common_tags
}

# Restore testing selection for RDS
resource "aws_backup_restore_testing_selection" "rds" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name                      = "${var.app_name}_rds_restore_test"
  restore_testing_plan_name = aws_backup_restore_testing_plan.weekly[0].name
  protected_resource_type   = "RDS"
  iam_role_arn              = aws_iam_role.restore_testing[0].arn

  protected_resource_conditions {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = "production"
    }
  }

  restore_metadata_overrides = {
    dbinstanceclass    = "db.t3.micro" # Use small instance for testing
    publiclyaccessible = "false"
    multiaz            = "false"
    allocatedstorage   = "20"
  }

  validation_window_hours = 2 # Allow 2 hours for validation
}

# Restore testing selection for EBS volumes
resource "aws_backup_restore_testing_selection" "ebs" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name                      = "${var.app_name}_ebs_restore_test"
  restore_testing_plan_name = aws_backup_restore_testing_plan.weekly[0].name
  protected_resource_type   = "EBS"
  iam_role_arn              = aws_iam_role.restore_testing[0].arn

  protected_resource_conditions {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = "production"
    }
  }

  restore_metadata_overrides = {
    volumetype       = "gp3"
    availabilityzone = "${var.aws_region}a"
  }

  validation_window_hours = 1 # Allow 1 hour for validation
}

# ========================================
# AWS Backup Audit Manager (Production Only)
# ========================================

resource "aws_backup_framework" "hipaa" {
  count = var.enable_backup_audit_manager && var.enable_hipaa_framework && var.environment == "production" ? 1 : 0

  name        = "${var.app_name}_hipaa_backup_compliance"
  description = "HIPAA backup compliance framework - Production resources only"

  control {
    name = "BACKUP_RECOVERY_POINT_MINIMUM_RETENTION_CHECK"

    input_parameter {
      name  = "requiredRetentionDays"
      value = "35"
    }

    scope {
      tags = {
        Environment = "production"
      }
    }
  }

  control {
    name = "BACKUP_RECOVERY_POINT_ENCRYPTED"

    scope {
      tags = {
        Environment = "production"
      }
    }
  }

  control {
    name = "BACKUP_RESOURCES_PROTECTED_BY_BACKUP_PLAN"

    scope {
      tags = {
        Environment = "production"
      }
    }
  }

  control {
    name = "BACKUP_PLAN_MIN_FREQUENCY_AND_MIN_RETENTION_CHECK"

    input_parameter {
      name  = "requiredFrequencyUnit"
      value = "days"
    }

    input_parameter {
      name  = "requiredFrequencyValue"
      value = "1"
    }

    input_parameter {
      name  = "requiredRetentionDays"
      value = "35"
    }

    scope {
      tags = {
        Environment = "production"
      }
    }
  }

  control {
    name = "BACKUP_RECOVERY_POINT_MANUAL_DELETION_DISABLED"

    scope {
      tags = {
        Environment = "production"
      }
    }
  }

  control {
    name = "BACKUP_LAST_RECOVERY_POINT_CREATED"

    input_parameter {
      name  = "recoveryPointAgeUnit"
      value = "days"
    }

    input_parameter {
      name  = "recoveryPointAgeValue"
      value = "1"
    }

    scope {
      tags = {
        Environment = "production"
      }
    }
  }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  tags = var.common_tags
}

# Backup audit report
resource "aws_backup_report_plan" "daily" {
  count = var.enable_backup_audit_manager && var.environment == "production" ? 1 : 0

  name        = "${var.app_name}_daily_backup_report"
  description = "Daily backup compliance report"

  report_delivery_channel {
    formats        = ["CSV", "JSON"]
    s3_bucket_name = var.config_bucket_name
    s3_key_prefix  = "backup-reports"
  }

  report_setting {
    report_template = "CONTROL_COMPLIANCE_REPORT"

    framework_arns = var.enable_hipaa_framework ? [aws_backup_framework.hipaa[0].arn] : []
  }

  tags = var.common_tags
}
