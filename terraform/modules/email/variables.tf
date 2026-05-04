variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region where SES is provisioned"
  type        = string
}

variable "caller_identity_account_id" {
  description = "AWS account ID used to scope the SNS topic policy that allows SES to publish events"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID. Required when manage_route53_records is true."
  type        = string
  default     = ""
}

variable "manage_route53_records" {
  description = "Create Route53 records for SES verification, DKIM, test domains, and custom MAIL FROM"
  type        = bool
  default     = true
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

variable "mail_from_subdomain" {
  description = "Subdomain label used for the SES custom MAIL FROM domain. Empty string disables custom MAIL FROM."
  type        = string
  default     = "mail"
}

variable "mail_from_behavior_on_mx_failure" {
  description = "SES behavior when the custom MAIL FROM MX record is not resolvable"
  type        = string
  default     = "UseDefaultValue"

  validation {
    condition     = contains(["UseDefaultValue", "RejectMessage"], var.mail_from_behavior_on_mx_failure)
    error_message = "mail_from_behavior_on_mx_failure must be either UseDefaultValue or RejectMessage."
  }
}

variable "enable_event_destination" {
  description = "Provision an SNS topic and SES configuration-set event destination for selected events"
  type        = bool
  default     = true
}

variable "event_matching_types" {
  description = "SES event types routed to the SNS events topic"
  type        = list(string)
  default     = ["bounce", "complaint", "reject"]

  validation {
    condition = length([
      for event_type in var.event_matching_types : event_type
      if !contains(["send", "reject", "bounce", "complaint", "delivery", "open", "click", "renderingFailure"], event_type)
    ]) == 0
    error_message = "event_matching_types must only contain: send, reject, bounce, complaint, delivery, open, click, renderingFailure."
  }
}

variable "event_notification_emails" {
  description = "Email addresses to subscribe to the SES event SNS topic"
  type        = list(string)
  default     = []
}

variable "sns_kms_key_id" {
  description = "KMS key ID or alias used to encrypt SNS topics"
  type        = string
  default     = "alias/aws/sns"
}

variable "enable_account_suppression" {
  description = "Enable SES account-level suppression for bounced/complained recipients"
  type        = bool
  default     = true
}

variable "suppressed_reasons" {
  description = "Reasons that trigger account-level suppression"
  type        = list(string)
  default     = ["BOUNCE", "COMPLAINT"]
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
