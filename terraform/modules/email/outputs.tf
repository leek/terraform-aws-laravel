output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "ses_configuration_set_arn" {
  description = "ARN of the SES configuration set"
  value       = aws_ses_configuration_set.main.arn
}

output "ses_configuration_set_name" {
  description = "Name of the SES configuration set"
  value       = aws_ses_configuration_set.main.name
}

output "ses_verification_token" {
  description = "TXT record value for SES domain verification"
  value       = aws_ses_domain_identity.main.verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for SES"
  value       = aws_ses_domain_dkim.main.dkim_tokens
}

output "ses_test_domain_verification_records" {
  description = "TXT records required to verify SES test domains"
  value = [
    for index, domain in var.test_email_domains : {
      name  = "_amazonses.${domain}"
      type  = "TXT"
      value = aws_ses_domain_identity.test_domains[index].verification_token
    }
  ]
}

output "ses_mail_from_domain" {
  description = "Custom MAIL FROM domain, or empty string when disabled"
  value       = local.mail_from_enabled ? local.mail_from_domain : ""
}

output "ses_mail_from_mx_value" {
  description = "MX record target for the custom MAIL FROM subdomain"
  value       = local.mail_from_enabled ? local.mail_from_mx : ""
}

output "ses_mail_from_spf_value" {
  description = "SPF TXT record value for the custom MAIL FROM subdomain"
  value       = local.mail_from_enabled ? local.mail_from_spf : ""
}

output "ses_root_spf_value" {
  description = "SPF TXT value for the root domain"
  value       = local.root_spf
}

output "ses_events_sns_topic_arn" {
  description = "SNS topic that receives SES events, or null when disabled"
  value       = var.enable_event_destination ? aws_sns_topic.events[0].arn : null
}
