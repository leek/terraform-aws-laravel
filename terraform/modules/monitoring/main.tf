# ========================================
# CloudWatch Log Groups
# ========================================

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.app_name}-${var.environment}"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-logs"
  })
}

# ========================================
# SNS Topic for Alerts
# ========================================

resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-${var.environment}-alerts"

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-alerts"
  })
}

# ========================================
# CloudTrail (Optional)
# ========================================

resource "aws_cloudtrail" "main" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${var.app_name}-${var.environment}-cloudtrail"
  s3_bucket_name = var.cloudtrail_bucket_name


  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cloudtrail"
  })
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
  count = length(var.healthcheck_alarm_emails) > 0 ? 1 : 0
  name  = "${var.app_name}-${var.environment}-health-check-alerts"

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