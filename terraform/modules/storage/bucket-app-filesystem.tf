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

resource "aws_s3_bucket_policy" "app_filesystem" {
  bucket = aws_s3_bucket.app_filesystem.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "AllowMacieToGetObjects"
        Effect = "Allow"
        Principal = {
          Service = "macie.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.app_filesystem.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.caller_identity_account_id
          }
        }
      },
      {
        Sid    = "AllowMacieToGetBucketInfo"
        Effect = "Allow"
        Principal = {
          Service = "macie.amazonaws.com"
        }
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.app_filesystem.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.caller_identity_account_id
          }
        }
      }
      ], var.enable_cloudfront ? [
      {
        Sid    = "AllowCloudFrontGetPublicObjects"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.app_filesystem.arn}/public/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.app_filesystem[0].arn
          }
        }
      }
    ] : [])
  })
}