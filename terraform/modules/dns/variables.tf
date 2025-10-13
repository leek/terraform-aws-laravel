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

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "dmarc_record" {
  description = "DMARC TXT record value"
  type        = string
  default     = ""
}