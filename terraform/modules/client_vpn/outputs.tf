output "client_vpn_endpoint_id" {
  description = "ID of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.id
}

output "client_vpn_endpoint_arn" {
  description = "ARN of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.arn
}

output "dns_name" {
  description = "DNS name of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}

output "self_service_portal_url" {
  description = "Self-service portal URL"
  value       = "https://self-service.clientvpn.amazonaws.com/endpoints/${aws_ec2_client_vpn_endpoint.main.id}"
}

output "association_id" {
  description = "ID of the network association"
  value       = aws_ec2_client_vpn_network_association.main.id
}