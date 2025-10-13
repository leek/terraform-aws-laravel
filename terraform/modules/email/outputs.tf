output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "ses_configuration_set_arn" {
  description = "ARN of the SES configuration set"
  value       = aws_ses_configuration_set.main.arn
}