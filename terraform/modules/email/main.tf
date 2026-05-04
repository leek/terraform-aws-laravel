# ========================================
# SES Configuration
# ========================================

locals {
  name_prefix       = "${var.app_name}-${var.environment}"
  mail_from_enabled = var.mail_from_subdomain != ""
  mail_from_domain  = local.mail_from_enabled ? "${var.mail_from_subdomain}.${var.domain_name}" : ""
  mail_from_mx      = "feedback-smtp.${var.aws_region}.amazonses.com"
  mail_from_spf     = "v=spf1 include:amazonses.com -all"
  root_spf          = "v=spf1 include:amazonses.com ~all"
}

# Domain identity
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# DKIM configuration
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_ses_domain_mail_from" "main" {
  count                  = local.mail_from_enabled ? 1 : 0
  domain                 = aws_ses_domain_identity.main.domain
  mail_from_domain       = local.mail_from_domain
  behavior_on_mx_failure = var.mail_from_behavior_on_mx_failure
}

# Domain verification TXT record
resource "aws_route53_record" "ses_verification" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.main.verification_token]
}

# DKIM DNS records
resource "aws_route53_record" "ses_dkim" {
  count   = var.manage_route53_records ? 3 : 0
  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "mail_from_mx" {
  count   = var.manage_route53_records && local.mail_from_enabled ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 ${local.mail_from_mx}"]
}

resource "aws_route53_record" "mail_from_spf" {
  count   = var.manage_route53_records && local.mail_from_enabled ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = [local.mail_from_spf]
}

# SES configuration set
resource "aws_ses_configuration_set" "main" {
  name = local.name_prefix

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
}

# Test email addresses for sandbox mode (individual emails - fallback option)
resource "aws_ses_email_identity" "test_emails" {
  for_each = toset(var.test_email_addresses)
  email    = each.value
}

# Test email domains for sandbox mode (allows sending to any email at these domains)
resource "aws_ses_domain_identity" "test_domains" {
  count  = length(var.test_email_domains)
  domain = var.test_email_domains[count.index]
}

# DNS verification for test domains
resource "aws_route53_record" "test_domain_verification" {
  count   = var.manage_route53_records && length(var.test_email_domains) > 0 && var.test_domain_route53_zone_id != "" ? length(var.test_email_domains) : 0
  zone_id = var.test_domain_route53_zone_id
  name    = "_amazonses.${var.test_email_domains[count.index]}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.test_domains[count.index].verification_token]
}

resource "aws_sns_topic" "events" {
  count = var.enable_event_destination ? 1 : 0

  name              = "${local.name_prefix}-ses-events"
  kms_master_key_id = var.sns_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ses-events"
  })
}

data "aws_iam_policy_document" "events_topic_policy" {
  count = var.enable_event_destination ? 1 : 0

  statement {
    sid    = "AllowSESPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.events[0].arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.caller_identity_account_id]
    }
  }
}

resource "aws_sns_topic_policy" "events" {
  count = var.enable_event_destination ? 1 : 0

  arn    = aws_sns_topic.events[0].arn
  policy = data.aws_iam_policy_document.events_topic_policy[0].json
}

resource "aws_ses_event_destination" "sns" {
  count = var.enable_event_destination ? 1 : 0

  name                   = "sns-events"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = var.event_matching_types

  sns_destination {
    topic_arn = aws_sns_topic.events[0].arn
  }
}

resource "aws_sns_topic_subscription" "event_email" {
  for_each = var.enable_event_destination ? toset(var.event_notification_emails) : toset([])

  topic_arn = aws_sns_topic.events[0].arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sesv2_account_suppression_attributes" "main" {
  count = var.enable_account_suppression ? 1 : 0

  suppressed_reasons = var.suppressed_reasons
}
