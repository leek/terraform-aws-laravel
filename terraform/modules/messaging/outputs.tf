# SQS Outputs
output "queue_url" {
  description = "URL of the main SQS queue"
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "ARN of the main SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "Name of the main SQS queue"
  value       = aws_sqs_queue.main.name
}

output "deadletter_queue_arn" {
  description = "ARN of the deadletter SQS queue"
  value       = aws_sqs_queue.deadletter.arn
}

output "deadletter_queue_url" {
  description = "URL of the SQS dead letter queue"
  value       = aws_sqs_queue.deadletter.url
}

