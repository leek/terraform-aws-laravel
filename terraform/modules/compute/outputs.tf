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