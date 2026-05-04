# ========================================
# CloudWatch Log Groups
# ========================================

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.app_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.cloudwatch_logs_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-logs"
  })
}

# ========================================
# SNS Topic for Alerts
# ========================================

resource "aws_sns_topic" "alerts" {
  name              = "${var.app_name}-${var.environment}-alerts"
  kms_master_key_id = var.sns_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-alerts"
  })
}

data "aws_iam_policy_document" "alerts_topic" {
  statement {
    sid    = "AllowCloudTrailPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${var.aws_region}:${var.caller_identity_account_id}:trail/${var.app_name}-${var.environment}-cloudtrail"]
    }
  }

  statement {
    sid    = "AllowCloudWatchPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.caller_identity_account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts_topic.json
}

# ========================================
# CloudTrail (Optional)
# ========================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name              = "/aws/cloudtrail/${var.app_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.cloudwatch_logs_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cloudtrail-logs"
  })
}

data "aws_iam_policy_document" "cloudtrail_assume_role" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.enable_cloudtrail ? 1 : 0

  name               = "${var.app_name}-${var.environment}-cloudtrail-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role[0].json

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cloudtrail-cloudwatch"
  })
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.enable_cloudtrail ? 1 : 0

  name   = "${var.app_name}-${var.environment}-cloudtrail-cloudwatch"
  role   = aws_iam_role.cloudtrail_cloudwatch[0].id
  policy = data.aws_iam_policy_document.cloudtrail_cloudwatch[0].json
}

resource "aws_cloudtrail" "main" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "${var.app_name}-${var.environment}-cloudtrail"
  s3_bucket_name                = var.cloudtrail_bucket_name
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch[0].arn
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = true
  kms_key_id                    = var.cloudtrail_kms_key_arn
  sns_topic_name                = aws_sns_topic.alerts.name


  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cloudtrail"
  })

  depends_on = [
    aws_iam_role_policy.cloudtrail_cloudwatch,
    aws_sns_topic_policy.alerts
  ]
}

# ========================================
# Route53 Health Check
# ========================================

resource "aws_route53_health_check" "main" {
  fqdn              = var.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/up"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-health-check"
  })
}

# ========================================
# CloudWatch Alarm for Health Check
# ========================================

resource "aws_cloudwatch_metric_alarm" "health_check" {
  alarm_name          = "${var.app_name}-${var.environment}-endpoint-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "This metric monitors whether the ${var.environment} endpoint is healthy"
  alarm_actions       = length(var.healthcheck_alarm_emails) > 0 ? [aws_sns_topic.health_check_alerts[0].arn] : []

  dimensions = {
    HealthCheckId = aws_route53_health_check.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-health-check-alarm"
  })
}

# ========================================
# SNS Topic for Health Check Alerts
# ========================================

resource "aws_sns_topic" "health_check_alerts" {
  count             = length(var.healthcheck_alarm_emails) > 0 ? 1 : 0
  name              = "${var.app_name}-${var.environment}-health-check-alerts"
  kms_master_key_id = var.sns_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-health-check-alerts"
  })
}

resource "aws_sns_topic_subscription" "health_check_email" {
  for_each  = toset(var.healthcheck_alarm_emails)
  topic_arn = aws_sns_topic.health_check_alerts[0].arn
  protocol  = "email"
  endpoint  = each.value
}
