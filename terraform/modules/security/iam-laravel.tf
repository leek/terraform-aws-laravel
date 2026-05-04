# ========================================
# Laravel Application IAM User
# ========================================

# IAM user for Laravel application with same permissions as ECS task role
resource "aws_iam_user" "laravel_app_user" {
  name = "${var.app_name}-${var.environment}-laravel-user"

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-laravel-user"
  })
}

# IAM access keys for Laravel
resource "aws_iam_access_key" "laravel_app_user" {
  user = aws_iam_user.laravel_app_user.name
}

# Attach the same policy as ECS task role to Laravel user
resource "aws_iam_user_policy" "laravel_app_user_policy" {
  name = "${var.app_name}-${var.environment}-laravel-user-policy"
  user = aws_iam_user.laravel_app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.caller_identity_account_id}:parameter/${var.app_name}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.main["parameter_store"].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.main["sqs"].arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${var.caller_identity_account_id}:*-${var.app_name}-${var.environment}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectAcl",
          "s3:PutObjectAcl",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.app_name}-${var.environment}-filesystem-*",
          "arn:aws:s3:::${var.app_name}-${var.environment}-filesystem-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.main["s3_filesystem"].arn
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "arn:aws:ses:${var.aws_region}:${var.caller_identity_account_id}:identity/*"
      }
    ]
  })
}
