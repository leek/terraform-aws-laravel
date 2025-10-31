# KMS Outputs
output "parameter_store_kms_key_id" {
  description = "KMS key ID for Parameter Store encryption"
  value       = aws_kms_key.parameter_store.key_id
}

output "parameter_store_kms_key_arn" {
  description = "KMS key ARN for Parameter Store encryption"
  value       = aws_kms_key.parameter_store.arn
}

output "rds_kms_key_id" {
  description = "KMS key ID for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "rds_kms_key_arn" {
  description = "KMS key ARN for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "sqs_kms_key_id" {
  description = "KMS key ID for SQS encryption"
  value       = aws_kms_key.sqs.key_id
}

output "sqs_kms_key_arn" {
  description = "KMS key ARN for SQS encryption"
  value       = aws_kms_key.sqs.arn
}

output "s3_filesystem_kms_key_id" {
  description = "KMS key ID for S3 filesystem encryption"
  value       = aws_kms_key.s3_filesystem.key_id
}

output "s3_filesystem_kms_key_arn" {
  description = "KMS key ARN for S3 filesystem encryption"
  value       = aws_kms_key.s3_filesystem.arn
}

output "backup_kms_key_id" {
  description = "KMS key ID for AWS Backup encryption"
  value       = aws_kms_key.backup.key_id
}

output "backup_kms_key_arn" {
  description = "KMS key ARN for AWS Backup encryption"
  value       = aws_kms_key.backup.arn
}

# IAM Outputs
output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = aws_iam_role.github_actions.arn
}

# Laravel Application User Outputs
output "laravel_user_access_key_id" {
  description = "Access Key ID for Laravel application"
  value       = aws_iam_access_key.laravel_app_user.id
  sensitive   = true
}

output "laravel_user_secret_access_key" {
  description = "Secret Access Key for Laravel application"
  value       = aws_iam_access_key.laravel_app_user.secret
  sensitive   = true
}