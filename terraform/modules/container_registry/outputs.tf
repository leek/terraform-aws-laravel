output "repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.main.arn
}

output "base_repository_url" {
  description = "URL of the shared base image ECR repository (only created in production)"
  value       = aws_ecr_repository.base.repository_url
}

output "base_repository_arn" {
  description = "ARN of the shared base image ECR repository (only created in production)"
  value       = aws_ecr_repository.base.arn
}
