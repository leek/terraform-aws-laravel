# ========================================
# KMS Keys
# ========================================

# Parameter Store KMS Key
resource "aws_kms_key" "parameter_store" {
  description             = "KMS key for ${var.app_name}-${var.environment} Parameter Store encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-parameter-store-key"
  })
}

resource "aws_kms_alias" "parameter_store" {
  name          = "alias/${var.app_name}-${var.environment}-parameter-store"
  target_key_id = aws_kms_key.parameter_store.key_id
}

# RDS KMS Key
resource "aws_kms_key" "rds" {
  description             = "KMS key for ${var.app_name}-${var.environment} RDS encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-rds-key"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.app_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# SQS KMS Key
resource "aws_kms_key" "sqs" {
  description             = "KMS key for ${var.app_name}-${var.environment} SQS encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-sqs-key"
  })
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/${var.app_name}-${var.environment}-sqs"
  target_key_id = aws_kms_key.sqs.key_id
}

# S3 Filesystem KMS Key
resource "aws_kms_key" "s3_filesystem" {
  description             = "KMS key for ${var.app_name}-${var.environment} S3 filesystem encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.caller_identity_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Macie to use KMS key for S3 operations"
        Effect = "Allow"
        Principal = {
          Service = "macie.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.caller_identity_account_id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-s3-filesystem-key"
  })
}

resource "aws_kms_alias" "s3_filesystem" {
  name          = "alias/${var.app_name}-${var.environment}-s3-filesystem"
  target_key_id = aws_kms_key.s3_filesystem.key_id
}

# AWS Backup KMS Key
resource "aws_kms_key" "backup" {
  description             = "KMS key for ${var.app_name}-${var.environment} AWS Backup encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-backup-key"
  })
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.app_name}-${var.environment}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# CloudWatch Logs KMS Key
resource "aws_kms_key" "cloudwatch_logs" {
  description             = "KMS key for ${var.app_name}-${var.environment} CloudWatch Logs encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.caller_identity_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${var.caller_identity_account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cloudwatch-logs-key"
  })
}

resource "aws_kms_alias" "cloudwatch_logs" {
  name          = "alias/${var.app_name}-${var.environment}-cloudwatch-logs"
  target_key_id = aws_kms_key.cloudwatch_logs.key_id
}

# ========================================
# ECS IAM Roles
# ========================================

# ECS Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.app_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-ecs-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add SSM permissions to ECS execution role for pulling secrets
resource "aws_iam_role_policy" "ecs_execution_role_ssm_policy" {
  name = "${var.app_name}-${var.environment}-ecs-execution-ssm-policy"
  role = aws_iam_role.ecs_execution_role.id

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
        Resource = aws_kms_key.parameter_store.arn
      }
    ]
  })
}

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-ecs-task-role"
  })
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "${var.app_name}-${var.environment}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

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
        Resource = aws_kms_key.parameter_store.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.sqs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
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
        Resource = [
          "arn:aws:sqs:${var.aws_region}:${var.caller_identity_account_id}:${var.app_name}-${var.environment}-queue",
          "arn:aws:sqs:${var.aws_region}:${var.caller_identity_account_id}:${var.app_name}-${var.environment}-deadletter"
        ]
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
        Resource = aws_kms_key.s3_filesystem.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# ========================================
# GitHub Actions IAM
# ========================================

# Get existing GitHub OIDC provider if not creating it
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# GitHub OIDC Provider (conditional - only create once per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-github-oidc"
  })
}

# GitHub Actions Role
resource "aws_iam_role" "github_actions" {
  name = "${var.app_name}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-github-actions-role"
  })
}

resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.app_name}-${var.environment}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR - Docker image push/pull
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*" # Required for ECR login
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${var.caller_identity_account_id}:repository/${var.app_name}-${var.environment}",
          "arn:aws:ecr:${var.aws_region}:${var.caller_identity_account_id}:repository/${var.app_name}-${var.environment}-*"
        ]
      },
      # ECS - Actions that require wildcard resource
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*" # These actions don't support resource-level permissions
      },
      # ECS - Service deployment and task execution with specific resources
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:UpdateService",
          "ecs:RunTask"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:service/${var.app_name}-${var.environment}/*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:task/${var.app_name}-${var.environment}/*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:task-definition/${var.app_name}-${var.environment}:*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:task-definition/${var.app_name}-${var.environment}-*:*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:cluster/${var.app_name}-${var.environment}"
        ]
      },
      # CloudWatch Logs - Read deployment logs for debugging
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.caller_identity_account_id}:log-group:/aws/ecs/${var.app_name}-${var.environment}:*"
        ]
      },
      # IAM PassRole - Allow ECS to assume execution and task roles
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

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
        Resource = aws_kms_key.parameter_store.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.sqs.arn
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
        Resource = [
          "arn:aws:sqs:${var.aws_region}:${var.caller_identity_account_id}:${var.app_name}-${var.environment}-queue",
          "arn:aws:sqs:${var.aws_region}:${var.caller_identity_account_id}:${var.app_name}-${var.environment}-deadletter"
        ]
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
        Resource = aws_kms_key.s3_filesystem.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}
