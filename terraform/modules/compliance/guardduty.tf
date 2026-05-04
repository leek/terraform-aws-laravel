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