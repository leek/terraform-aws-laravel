# ========================================
# Route53 DNS Records
# ========================================

locals {
  # When the app CloudFront distribution is in front of the ALB, alias the app
  # records to it instead. CloudFront aliases require evaluate_target_health = false.
  app_alias_name                   = var.cloudfront_app_enabled ? var.cloudfront_app_domain_name : var.alb_dns_name
  app_alias_zone_id                = var.cloudfront_app_enabled ? var.cloudfront_app_hosted_zone_id : var.alb_zone_id
  app_alias_evaluate_target_health = var.cloudfront_app_enabled ? false : true
}

# Main domain A record
resource "aws_route53_record" "main" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = local.app_alias_name
    zone_id                = local.app_alias_zone_id
    evaluate_target_health = local.app_alias_evaluate_target_health
  }
}

# Wildcard subdomain A record
resource "aws_route53_record" "wildcard" {
  zone_id = var.route53_zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name                   = local.app_alias_name
    zone_id                = local.app_alias_zone_id
    evaluate_target_health = local.app_alias_evaluate_target_health
  }
}

# WWW subdomain A record (for www to non-www redirect)
resource "aws_route53_record" "www" {
  zone_id = var.route53_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = local.app_alias_name
    zone_id                = local.app_alias_zone_id
    evaluate_target_health = local.app_alias_evaluate_target_health
  }
}

# DMARC record (only created if dmarc_record is set)
resource "aws_route53_record" "dmarc" {
  count   = var.dmarc_record != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = [var.dmarc_record]
}