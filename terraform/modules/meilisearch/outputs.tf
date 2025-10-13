# Meilisearch Outputs
output "meilisearch_endpoint" {
  description = "Meilisearch service endpoint"
  value       = "http://meilisearch.${aws_service_discovery_private_dns_namespace.meilisearch.name}:7700"
}

output "meilisearch_host" {
  description = "Meilisearch host for internal access"
  value       = "meilisearch.${aws_service_discovery_private_dns_namespace.meilisearch.name}"
}

output "meilisearch_port" {
  description = "Meilisearch port"
  value       = 7700
}

output "meilisearch_security_group_id" {
  description = "Meilisearch security group ID"
  value       = aws_security_group.meilisearch.id
}

output "service_discovery_namespace_id" {
  description = "Service discovery namespace ID"
  value       = aws_service_discovery_private_dns_namespace.meilisearch.id
}