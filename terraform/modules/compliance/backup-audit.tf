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