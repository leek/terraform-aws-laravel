# Macie Findings Bucket
resource "aws_s3_bucket" "macie_findings" {
  bucket = "${var.app_name}-${var.environment}-macie-findings-${random_string.bucket_suffix.result}"

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-macie-findings"
  })
}

resource "aws_s3_bucket_policy" "macie_findings" {
  bucket = aws_s3_bucket.macie_findings.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowMacieToWriteFindings"
        Effect = "Allow"
        Principal = {
          Service = "macie.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.macie_findings.arn}/*"
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
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.macie_findings.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.caller_identity_account_id
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "macie_findings" {
  bucket = aws_s3_bucket.macie_findings.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.s3_filesystem_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "macie_findings" {
  bucket = aws_s3_bucket.macie_findings.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "macie_findings" {
  bucket = aws_s3_bucket.macie_findings.id

  rule {
    id     = "delete_old_findings"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_public_access_block" "macie_findings" {
  bucket = aws_s3_bucket.macie_findings.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}