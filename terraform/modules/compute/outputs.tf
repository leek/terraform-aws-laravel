# ECS Outputs
output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "ecs_session_manager_command" {
  description = "Command to connect to ECS container via Session Manager"
  value       = "aws ecs execute-command --cluster ${module.ecs.cluster_name} --task <task-id> --container app --interactive --command '/bin/bash'"
}

output "queue_worker_service_name" {
  description = "Name of the queue worker ECS service"
  value       = var.enable_queue_worker ? aws_ecs_service.worker["queue-worker"].name : null
}

output "scheduler_service_name" {
  description = "Name of the scheduler ECS service"
  value       = var.enable_scheduler ? aws_ecs_service.worker["scheduler"].name : null
}

output "nightwatch_service_name" {
  description = "Name of the Nightwatch ECS service"
  value       = var.enable_nightwatch ? aws_ecs_service.worker["nightwatch"].name : null
}

output "worker_services" {
  description = "Map of all worker service names"
  value       = { for k, v in aws_ecs_service.worker : k => v.name }
}