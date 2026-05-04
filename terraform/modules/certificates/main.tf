# ========================================
# SSL Certificate
# ========================================

locals {
  create_primary_certificate = var.certificate_arn == ""
  create_vpn_certificate     = var.vpn_server_certificate_arn == ""
  vanity_domains_to_create = {
    for vanity_domain in var.vanity_domains : vanity_domain.domain => vanity_domain
    if vanity_domain.certificate_arn == ""
  }
}

# Request SSL certificate with SAN
resource "aws_acm_certificate" "main" {
  count = local.create_primary_certificate ? 1 : 0

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

moved {
  from = aws_acm_certificate.main
  to   = aws_acm_certificate.main[0]
}

# Create DNS validation records
resource "aws_route53_record" "certificate_validation" {
  for_each = var.manage_route53_records && local.create_primary_certificate ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
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
  count = local.create_primary_certificate && var.wait_for_validation ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = var.manage_route53_records ? [for record in aws_route53_record.certificate_validation : record.fqdn] : null

  timeouts {
    create = var.manage_route53_records ? "5m" : "45m"
  }
}

moved {
  from = aws_acm_certificate_validation.main
  to   = aws_acm_certificate_validation.main[0]
}

# ========================================
# VPN Server Certificate
# ========================================

# Request VPN server certificate
resource "aws_acm_certificate" "vpn_server" {
  count = local.create_vpn_certificate ? 1 : 0

  domain_name       = "vpn.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-vpn-server-cert"
  })
}

moved {
  from = aws_acm_certificate.vpn_server
  to   = aws_acm_certificate.vpn_server[0]
}

# Create DNS validation records for VPN certificate
resource "aws_route53_record" "vpn_certificate_validation" {
  for_each = var.manage_route53_records && local.create_vpn_certificate ? {
    for dvo in aws_acm_certificate.vpn_server[0].domain_validation_options : dvo.domain_name => {
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
  count = local.create_vpn_certificate && var.wait_for_validation ? 1 : 0

  certificate_arn         = aws_acm_certificate.vpn_server[0].arn
  validation_record_fqdns = var.manage_route53_records ? [for record in aws_route53_record.vpn_certificate_validation : record.fqdn] : null

  timeouts {
    create = var.manage_route53_records ? "5m" : "45m"
  }
}

moved {
  from = aws_acm_certificate_validation.vpn_server
  to   = aws_acm_certificate_validation.vpn_server[0]
}

# Vanity domain certificates are commonly used for external DNS domains. DNS
# validation records are exposed as outputs and are not managed by Route53 here.
resource "aws_acm_certificate" "vanity" {
  for_each = local.vanity_domains_to_create

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
  for_each = var.wait_for_validation ? aws_acm_certificate.vanity : {}

  certificate_arn = each.value.arn

  timeouts {
    create = "45m"
  }
}
