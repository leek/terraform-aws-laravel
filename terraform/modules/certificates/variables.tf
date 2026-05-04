variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID. Required when manage_route53_records is true."
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "Existing ACM certificate ARN for the primary app domain. Empty requests a new certificate."
  type        = string
  default     = ""
}

variable "vpn_server_certificate_arn" {
  description = "Existing ACM certificate ARN for the VPN server domain. Empty requests a new certificate."
  type        = string
  default     = ""
}

variable "manage_route53_records" {
  description = "Create Route53 DNS validation records for primary and VPN certificates"
  type        = bool
  default     = true
}

variable "wait_for_validation" {
  description = "Wait for ACM certificates to be DNS validated before exposing them for dependent resources"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "vanity_domains" {
  description = "External vanity domains requiring separate ACM certificates"
  type = list(object({
    domain          = string
    certificate_arn = optional(string, "")
  }))
  default = []
}
