# ========================================
# SES Configuration
# ========================================

# Domain identity
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# DKIM configuration
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# Domain verification TXT record
resource "aws_route53_record" "ses_verification" {
  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.main.verification_token]
}

# DKIM DNS records
resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# SES configuration set
resource "aws_ses_configuration_set" "main" {
  name = "${var.app_name}-${var.environment}"

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
}

# Test email addresses for sandbox mode
resource "aws_ses_email_identity" "test_emails" {
  for_each = toset(var.test_email_addresses)
  email    = each.value
}