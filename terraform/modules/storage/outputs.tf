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


