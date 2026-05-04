# ========================================
# CloudFront CDN (Optional)
# ========================================

resource "aws_cloudfront_origin_access_control" "s3" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = "${var.app_name}-${var.environment}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "app_filesystem" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  aliases             = ["cdn.${var.domain_name}"]
  default_root_object = ""

  origin {
    domain_name              = aws_s3_bucket.app_filesystem.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.app_filesystem.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${aws_s3_bucket.app_filesystem.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
    compress    = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cdn"
  })
}

moved {
  from = aws_cloudfront_distribution.cdn[0]
  to   = aws_cloudfront_distribution.app_filesystem[0]
}