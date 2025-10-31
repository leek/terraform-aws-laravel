variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "test_email_addresses" {
  description = "List of individual test email addresses for SES sandbox (fallback option)"
  type        = list(string)
  default     = []
}

variable "test_email_domains" {
  description = "List of domains to verify for SES sandbox (allows sending to any email at these domains)"
  type        = list(string)
  default     = []
}

variable "test_domain_route53_zone_id" {
  description = "Route53 hosted zone ID for test email domains (required if test_email_domains is set)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}