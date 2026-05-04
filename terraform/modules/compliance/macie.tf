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