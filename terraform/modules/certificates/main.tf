# ========================================
# SSL Certificate
# ========================================

# Request SSL certificate with SAN
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cert"
  })
}

# Create DNS validation records
resource "aws_route53_record" "certificate_validation" {
  for_each = var.manage_route53_records ? {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Validate the certificate
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# ========================================
# VPN Server Certificate
# ========================================

# Request VPN server certificate
resource "aws_acm_certificate" "vpn_server" {
  domain_name       = "vpn.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-vpn-server-cert"
  })
}

# Create DNS validation records for VPN certificate
resource "aws_route53_record" "vpn_certificate_validation" {
  for_each = var.manage_route53_records ? {
    for dvo in toset(aws_acm_certificate.vpn_server.domain_validation_options) : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Validate the VPN certificate
resource "aws_acm_certificate_validation" "vpn_server" {
  certificate_arn         = aws_acm_certificate.vpn_server.arn
  validation_record_fqdns = [for record in aws_route53_record.vpn_certificate_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Vanity domain certificates are commonly used for external DNS domains. DNS
# validation records are exposed as outputs and are not managed by Route53 here.
resource "aws_acm_certificate" "vanity" {
  for_each = { for vanity_domain in var.vanity_domains : vanity_domain.domain => vanity_domain }

  domain_name               = each.key
  subject_alternative_names = ["*.${each.key}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-vanity-${replace(each.key, ".", "-")}"
  })
}

resource "aws_acm_certificate_validation" "vanity" {
  for_each = aws_acm_certificate.vanity

  certificate_arn = each.value.arn

  timeouts {
    create = "45m"
  }
}
