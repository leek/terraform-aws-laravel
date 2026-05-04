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

  timeouts {
    create = "10m"
  }

  depends_on = [aws_securityhub_account.main]
}

# AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "foundational" {
  count = var.enable_security_hub && var.enable_aws_foundational_standard && var.environment == "production" ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  timeouts {
    create = "10m"
  }

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