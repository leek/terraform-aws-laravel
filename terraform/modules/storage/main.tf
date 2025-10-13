# ========================================
# S3 Buckets
# ========================================

# Random suffix for bucket names to ensure uniqueness
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ALB Access Logs Bucket
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.app_name}-${var.environment}-alb-logs-${random_string.bucket_suffix.result}"

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-alb-logs"
  })
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root"  # ELB service account for us-east-1
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${var.caller_identity_account_id}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root"  # ELB service account for us-east-1
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${var.caller_identity_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "delete_old_logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudTrail Logs Bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.app_name}-${var.environment}-cloudtrail-${random_string.bucket_suffix.result}"

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cloudtrail"
  })
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.caller_identity_account_id}:trail/${var.app_name}-${var.environment}-cloudtrail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.caller_identity_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.caller_identity_account_id}:trail/${var.app_name}-${var.environment}-cloudtrail"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Application Filesystem Bucket
resource "aws_s3_bucket" "app_filesystem" {
  bucket = "${var.app_name}-${var.environment}-filesystem-${random_string.bucket_suffix.result}"

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-filesystem"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_filesystem" {
  bucket = aws_s3_bucket.app_filesystem.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.s3_filesystem_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "app_filesystem" {
  bucket = aws_s3_bucket.app_filesystem.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "app_filesystem" {
  bucket = aws_s3_bucket.app_filesystem.id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_filesystem" {
  bucket = aws_s3_bucket.app_filesystem.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "app_filesystem" {
  bucket = aws_s3_bucket.app_filesystem.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [
      "https://*.${var.domain_name}",
      "https://${var.domain_name}"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

