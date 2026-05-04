# ========================================
# KMS Keys
# ========================================

locals {
  kms_keys = {
    parameter_store = {
      description = "KMS key for ${var.app_name}-${var.environment} Parameter Store encryption"
      alias_name  = "alias/${var.app_name}-${var.environment}-parameter-store"
      tag_name    = "${var.app_name}-${var.environment}-parameter-store-key"
    }
    rds = {
      description = "KMS key for ${var.app_name}-${var.environment} RDS encryption"
      alias_name  = "alias/${var.app_name}-${var.environment}-rds"
      tag_name    = "${var.app_name}-${var.environment}-rds-key"
    }
    sqs = {
      description = "KMS key for ${var.app_name}-${var.environment} SQS encryption"
      alias_name  = "alias/${var.app_name}-${var.environment}-sqs"
      tag_name    = "${var.app_name}-${var.environment}-sqs-key"
    }
    s3_filesystem = {
      description = "KMS key for ${var.app_name}-${var.environment} S3 filesystem encryption"
      alias_name  = "alias/${var.app_name}-${var.environment}-s3-filesystem"
      tag_name    = "${var.app_name}-${var.environment}-s3-filesystem-key"
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
          },
          {
            Sid    = "Allow Macie service-linked role to use KMS key for S3 operations"
            Effect = "Allow"
            Principal = {
              AWS = "arn:aws:iam::${var.caller_identity_account_id}:role/aws-service-role/macie.amazonaws.com/AWSServiceRoleForAmazonMacie"
            }
            Action = [
              "kms:Decrypt",
              "kms:DescribeKey"
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
    }
    backup = {
      description = "KMS key for ${var.app_name}-${var.environment} AWS Backup encryption"
      alias_name  = "alias/${var.app_name}-${var.environment}-backup"
      tag_name    = "${var.app_name}-${var.environment}-backup-key"
    }
    cloudwatch_logs = {
      description = "KMS key for ${var.app_name}-${var.environment} CloudWatch Logs encryption"
      alias_name  = "alias/${var.app_name}-${var.environment}-cloudwatch-logs"
      tag_name    = "${var.app_name}-${var.environment}-cloudwatch-logs-key"
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
    }
  }
}

resource "aws_kms_key" "main" {
  for_each = local.kms_keys

  description             = each.value.description
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true
  policy                  = lookup(each.value, "policy", null)

  tags = merge(var.common_tags, {
    Name = each.value.tag_name
  })
}

resource "aws_kms_alias" "main" {
  for_each = local.kms_keys

  name          = each.value.alias_name
  target_key_id = aws_kms_key.main[each.key].key_id
}

# Migration blocks for existing state
moved {
  from = aws_kms_key.parameter_store
  to   = aws_kms_key.main["parameter_store"]
}

moved {
  from = aws_kms_alias.parameter_store
  to   = aws_kms_alias.main["parameter_store"]
}

moved {
  from = aws_kms_key.rds
  to   = aws_kms_key.main["rds"]
}

moved {
  from = aws_kms_alias.rds
  to   = aws_kms_alias.main["rds"]
}

moved {
  from = aws_kms_key.sqs
  to   = aws_kms_key.main["sqs"]
}

moved {
  from = aws_kms_alias.sqs
  to   = aws_kms_alias.main["sqs"]
}

moved {
  from = aws_kms_key.s3_filesystem
  to   = aws_kms_key.main["s3_filesystem"]
}

moved {
  from = aws_kms_alias.s3_filesystem
  to   = aws_kms_alias.main["s3_filesystem"]
}

moved {
  from = aws_kms_key.backup
  to   = aws_kms_key.main["backup"]
}

moved {
  from = aws_kms_alias.backup
  to   = aws_kms_alias.main["backup"]
}

moved {
  from = aws_kms_key.cloudwatch_logs
  to   = aws_kms_key.main["cloudwatch_logs"]
}

moved {
  from = aws_kms_alias.cloudwatch_logs
  to   = aws_kms_alias.main["cloudwatch_logs"]
}