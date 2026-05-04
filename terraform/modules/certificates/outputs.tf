output "certificate_arn" {
  description = "ARN of the ACM certificate ready for dependent resources, or empty if validation is deferred"
  value = var.certificate_arn != "" ? var.certificate_arn : (
    var.wait_for_validation ? try(aws_acm_certificate_validation.main[0].certificate_arn, "") : ""
  )
}

output "requested_certificate_arn" {
  description = "ARN of the requested primary ACM certificate, even when validation is deferred"
  value       = var.certificate_arn != "" ? var.certificate_arn : try(aws_acm_certificate.main[0].arn, "")
}

output "vpn_server_certificate_arn" {
  description = "ARN of the VPN server ACM certificate ready for dependent resources, or empty if validation is deferred"
  value = var.vpn_server_certificate_arn != "" ? var.vpn_server_certificate_arn : (
    var.wait_for_validation ? try(aws_acm_certificate_validation.vpn_server[0].certificate_arn, "") : ""
  )
}

output "requested_vpn_server_certificate_arn" {
  description = "ARN of the requested VPN server ACM certificate, even when validation is deferred"
  value       = var.vpn_server_certificate_arn != "" ? var.vpn_server_certificate_arn : try(aws_acm_certificate.vpn_server[0].arn, "")
}

output "certificate_domain_validation_options" {
  description = "DNS validation records for the primary certificate"
  value       = var.certificate_arn != "" ? [] : try(aws_acm_certificate.main[0].domain_validation_options, [])
}

output "certificate_validation_records" {
  description = "Simplified DNS validation records for the primary certificate"
  value = var.certificate_arn != "" ? [] : [
    for dvo in try(aws_acm_certificate.main[0].domain_validation_options, []) : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

output "vpn_certificate_domain_validation_options" {
  description = "DNS validation records for the VPN certificate"
  value       = var.vpn_server_certificate_arn != "" ? [] : try(aws_acm_certificate.vpn_server[0].domain_validation_options, [])
}

output "vpn_certificate_validation_records" {
  description = "Simplified DNS validation records for the VPN certificate"
  value = var.vpn_server_certificate_arn != "" ? [] : [
    for dvo in try(aws_acm_certificate.vpn_server[0].domain_validation_options, []) : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

output "vanity_domain_certificate_arns" {
  description = "Map of vanity domain to ACM certificate ARN ready for dependent resources"
  value = merge(
    { for vanity_domain in var.vanity_domains : vanity_domain.domain => vanity_domain.certificate_arn if vanity_domain.certificate_arn != "" },
    var.wait_for_validation ? { for domain, validation in aws_acm_certificate_validation.vanity : domain => validation.certificate_arn } : {}
  )
}

output "requested_vanity_domain_certificate_arns" {
  description = "Map of vanity domain to requested ACM certificate ARN, even when validation is deferred"
  value = merge(
    { for vanity_domain in var.vanity_domains : vanity_domain.domain => vanity_domain.certificate_arn if vanity_domain.certificate_arn != "" },
    { for domain, cert in aws_acm_certificate.vanity : domain => cert.arn }
  )
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
