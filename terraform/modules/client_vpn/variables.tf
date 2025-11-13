variable "name" {
  description = "Name for the Client VPN endpoint"
  type        = string
}

variable "description" {
  description = "Description for the Client VPN endpoint"
  type        = string
  default     = ""
}

variable "server_certificate_arn" {
  description = "ARN of the server certificate"
  type        = string
}

variable "client_cidr_block" {
  description = "CIDR block for client IP addresses"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["10.0.0.2"]
}

variable "split_tunnel" {
  description = "Whether to enable split tunnel"
  type        = bool
  default     = true
}

variable "vpn_port" {
  description = "VPN port"
  type        = number
  default     = 443
}

variable "transport_protocol" {
  description = "Transport protocol"
  type        = string
  default     = "udp"
}

variable "session_timeout_hours" {
  description = "Session timeout in hours"
  type        = number
  default     = 24
}

variable "saml_provider_arn" {
  description = "ARN of SAML provider"
  type        = string
}

variable "self_service_saml_provider_arn" {
  description = "ARN of self-service SAML provider"
  type        = string
}

variable "connection_log_enabled" {
  description = "Whether to enable connection logging"
  type        = bool
  default     = false
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group for connection logs"
  type        = string
  default     = null
}

variable "cloudwatch_log_stream" {
  description = "CloudWatch log stream for connection logs"
  type        = string
  default     = null
}

variable "cloudwatch_logs_kms_key_id" {
  description = "KMS key ID for CloudWatch Logs encryption"
  type        = optional(string)
  default     = null
}

variable "client_connect_enabled" {
  description = "Whether to enable client connect options"
  type        = bool
  default     = false
}

variable "login_banner_enabled" {
  description = "Whether to enable login banner"
  type        = bool
  default     = false
}

variable "login_banner_text" {
  description = "Login banner text"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID to associate with"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "target_subnet_id" {
  description = "Target subnet ID for VPN association"
  type        = string
}

variable "additional_authorized_cidrs" {
  description = "Additional CIDR blocks to authorize"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}