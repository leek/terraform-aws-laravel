output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "vpn_server_certificate_arn" {
  description = "ARN of the VPN server ACM certificate"
  value       = aws_acm_certificate_validation.vpn_server.certificate_arn
}