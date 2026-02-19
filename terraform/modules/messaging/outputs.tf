# SQS Outputs

output "sqs_suffix" {
  description = "SQS queue name suffix (e.g., -myapp-production)"
  value       = local.sqs_suffix
}

output "queue_names_csv" {
  description = "Comma-separated list of logical queue names for the worker"
  value       = join(",", var.queue_names)
}

output "queue_urls" {
  description = "Map of logical queue name to SQS queue URL"
  value       = { for k, q in aws_sqs_queue.queues : k => q.url }
}

output "queue_arns" {
  description = "Map of logical queue name to SQS queue ARN"
  value       = { for k, q in aws_sqs_queue.queues : k => q.arn }
}

output "deadletter_queue_arn" {
  description = "ARN of the deadletter SQS queue"
  value       = aws_sqs_queue.deadletter.arn
}

output "deadletter_queue_url" {
  description = "URL of the SQS dead letter queue"
  value       = aws_sqs_queue.deadletter.url
}
