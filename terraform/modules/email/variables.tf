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
  description = "List of test email addresses for SES sandbox"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}