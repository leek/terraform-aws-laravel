# ALB Outputs
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

# WAF Outputs
output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "app_cloudfront_distribution_domain" {
  description = "Domain name of the app CloudFront distribution, if enabled"
  value       = var.enable_cloudfront_app ? aws_cloudfront_distribution.app[0].domain_name : ""
}

output "app_cloudfront_distribution_id" {
  description = "ID of the app CloudFront distribution, if enabled"
  value       = var.enable_cloudfront_app ? aws_cloudfront_distribution.app[0].id : ""
}
