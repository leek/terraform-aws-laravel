output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives inbound SMS and delivery events"
  value       = aws_sns_topic.events.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.events.name
}

output "configuration_set_name" {
  description = "Name of the AWS End User Messaging SMS configuration set (matches AWS_SMS_CONFIGURATION_SET env var)"
  value       = aws_pinpointsmsvoicev2_configuration_set.this.name
}

output "configuration_set_arn" {
  description = "ARN of the configuration set"
  value       = aws_pinpointsmsvoicev2_configuration_set.this.arn
}

output "two_way_channel_role_arn" {
  description = "ARN of the IAM role assumed by sms-voice.amazonaws.com to publish to the SNS topic"
  value       = aws_iam_role.two_way_channel.arn
}

output "webhook_url" {
  description = "Application URL the SNS subscription delivers events to"
  value       = "https://${var.domain_name}${var.webhook_path}"
}
