output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.main.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = length(aws_cloudtrail.main) > 0 ? aws_cloudtrail.main[0].arn : null
}