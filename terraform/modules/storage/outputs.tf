# ALB Logs Bucket
output "alb_logs_bucket_name" {
  description = "Name of the ALB logs bucket"
  value       = aws_s3_bucket.alb_logs.bucket
}

output "alb_logs_bucket_arn" {
  description = "ARN of the ALB logs bucket"
  value       = aws_s3_bucket.alb_logs.arn
}

# CloudTrail Bucket
output "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail bucket"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_bucket_arn" {
  description = "ARN of the CloudTrail bucket"
  value       = aws_s3_bucket.cloudtrail.arn
}

# App Filesystem Bucket
output "app_filesystem_bucket_name" {
  description = "Name of the app filesystem bucket"
  value       = aws_s3_bucket.app_filesystem.bucket
}

output "app_filesystem_bucket_arn" {
  description = "ARN of the app filesystem bucket"
  value       = aws_s3_bucket.app_filesystem.arn
}

# AWS Config Bucket
output "config_bucket_name" {
  description = "Name of the AWS Config bucket"
  value       = aws_s3_bucket.config.bucket
}

output "config_bucket_arn" {
  description = "ARN of the AWS Config bucket"
  value       = aws_s3_bucket.config.arn
}

# VPC Flow Logs Bucket
output "vpc_flow_logs_bucket_name" {
  description = "Name of the VPC flow logs bucket"
  value       = aws_s3_bucket.vpc_flow_logs.bucket
}

output "vpc_flow_logs_bucket_arn" {
  description = "ARN of the VPC flow logs bucket"
  value       = aws_s3_bucket.vpc_flow_logs.arn
}

# Macie Findings Bucket
output "macie_findings_bucket_name" {
  description = "Name of the Macie findings bucket"
  value       = aws_s3_bucket.macie_findings.bucket
}

output "macie_findings_bucket_arn" {
  description = "ARN of the Macie findings bucket"
  value       = aws_s3_bucket.macie_findings.arn
}


