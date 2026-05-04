output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "vpn_server_certificate_arn" {
  description = "ARN of the VPN server ACM certificate"
  value       = aws_acm_certificate_validation.vpn_server.certificate_arn
}

output "certificate_domain_validation_options" {
  description = "DNS validation records for the primary certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}

output "vpn_certificate_domain_validation_options" {
  description = "DNS validation records for the VPN certificate"
  value       = aws_acm_certificate.vpn_server.domain_validation_options
}

output "vanity_domain_certificate_arns" {
  description = "Map of vanity domain to validated ACM certificate ARN"
  value       = { for domain, validation in aws_acm_certificate_validation.vanity : domain => validation.certificate_arn }
}

output "vanity_domain_validation_records" {
  description = "DNS validation records for vanity domain certificates"
  value = {
    for domain, cert in aws_acm_certificate.vanity : domain => [
      for dvo in cert.domain_validation_options : {
        name  = dvo.resource_record_name
        type  = dvo.resource_record_type
        value = dvo.resource_record_value
      }
    ]
  }
}
