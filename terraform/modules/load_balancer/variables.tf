variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "alb_logs_bucket_name" {
  description = "ALB logs S3 bucket name"
  type        = string
}

variable "enable_access_logs" {
  description = "Enable ALB access logging"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the load balancer"
  type        = bool
  default     = false
}

variable "drop_invalid_header_fields" {
  description = "Enable dropping of invalid HTTP header fields"
  type        = bool
  default     = true
}

variable "blocked_uri_patterns" {
  description = "List of URI patterns to block at the WAF level (e.g., ['/login/login.html', '/admin.php', '/.env'])"
  type        = list(string)
  default     = []
}

variable "enable_bot_control" {
  description = "Enable AWS WAF Bot Control managed rule set"
  type        = bool
  default     = false
}

variable "rate_limit_general" {
  description = "General WAF request rate limit per IP over a 5-minute window"
  type        = number
  default     = 2000
}

variable "rate_limit_livewire" {
  description = "WAF request rate limit per IP for Livewire endpoints over a 5-minute window"
  type        = number
  default     = 10000
}

variable "rate_limit_excluded_path_prefixes" {
  description = "Additional URI path prefixes excluded from the general rate limit"
  type        = list(string)
  default     = []
}

variable "rate_limit_excluded_exact_paths" {
  description = "Additional exact URI paths excluded from the general rate limit"
  type        = list(string)
  default     = []
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/up"
}

variable "enable_stickiness" {
  description = "Enable ALB target group stickiness"
  type        = bool
  default     = false
}

variable "ssl_policy" {
  description = "ALB HTTPS listener SSL policy"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "vanity_domains" {
  description = "Vanity domains with ALB certificate ARNs and redirect targets"
  type = list(object({
    domain          = string
    redirect_host   = string
    redirect_path   = string
    certificate_arn = string
  }))
  default = []
}

variable "enable_cloudfront_app" {
  description = "Enable a CloudFront distribution in front of the ALB"
  type        = bool
  default     = false
}

variable "cloudfront_app_aliases" {
  description = "Aliases for the app CloudFront distribution. Requires cloudfront_app_certificate_arn."
  type        = list(string)
  default     = []
}

variable "cloudfront_app_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for app CloudFront aliases. Empty uses the default CloudFront certificate."
  type        = string
  default     = ""
}

variable "cloudfront_app_price_class" {
  description = "CloudFront price class for the app distribution"
  type        = string
  default     = "PriceClass_100"
}
