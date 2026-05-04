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

variable "cloudfront_app_enabled" {
  description = "Point apex/www/wildcard records at the app CloudFront distribution instead of the ALB"
  type        = bool
  default     = false
}

variable "cloudfront_app_domain_name" {
  description = "App CloudFront distribution domain name (used when cloudfront_app_enabled = true)"
  type        = string
  default     = ""
}

variable "cloudfront_app_hosted_zone_id" {
  description = "App CloudFront hosted zone ID (always Z2FDTNDATAQYW2 for CloudFront aliases)"
  type        = string
  default     = ""
}