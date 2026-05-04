variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment (staging, uat, production)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Domain name where the inbound SMS webhook is reachable (e.g. app.example.com)"
  type        = string
}

variable "webhook_path" {
  description = "Path on the application that receives SNS notifications for SMS events"
  type        = string
  default     = "/api/webhooks/aws/sms/events"
}

variable "phone_number_id" {
  description = "Existing AWS End User Messaging SMS phone number ID (e.g. phone-abc123) to attach two-way SMS to. Leave empty to skip the attachment step and wire it manually."
  type        = string
  default     = ""
}

variable "configuration_set_name" {
  description = "Name of the AWS End User Messaging SMS configuration set. Must match the AWS_SMS_CONFIGURATION_SET env var consumed by the application."
  type        = string
}

variable "default_message_type" {
  description = "Default message type for the configuration set (TRANSACTIONAL or PROMOTIONAL)"
  type        = string
  default     = "TRANSACTIONAL"

  validation {
    condition     = contains(["TRANSACTIONAL", "PROMOTIONAL"], var.default_message_type)
    error_message = "default_message_type must be TRANSACTIONAL or PROMOTIONAL."
  }
}

variable "subscription_confirmation_timeout_minutes" {
  description = "How long Terraform waits for the application's webhook to confirm the SNS HTTPS subscription"
  type        = number
  default     = 3
}

variable "caller_identity_account_id" {
  description = "AWS account ID (for SNS topic policy SourceAccount condition)"
  type        = string
}

variable "sns_kms_key_id" {
  description = "KMS key ID or alias used to encrypt SNS topics"
  type        = string
  default     = "alias/aws/sns"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
