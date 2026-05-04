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