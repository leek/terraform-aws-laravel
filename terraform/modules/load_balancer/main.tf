# ========================================
# WAF v2 Configuration
# ========================================

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.app_name}-${var.environment}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Custom Rule - Block Specific URI Patterns
  dynamic "rule" {
    for_each = length(var.blocked_uri_patterns) > 0 ? [1] : []
    content {
      name     = "BlockSpecificURIPatterns"
      priority = 0

      action {
        block {}
      }

      statement {
        or_statement {
          dynamic "statement" {
            for_each = var.blocked_uri_patterns
            content {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "EXACTLY"
                search_string         = statement.value
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "BlockedURIPatterns"
        sampled_requests_enabled   = true
      }
    }
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            allow {}
          }
          name = "SizeRestrictions_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Amazon IP Reputation List
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AmazonIpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Bot Control Rule Set (~$10/mo flat + request fees)
  dynamic "rule" {
    for_each = var.enable_bot_control ? [1] : []
    content {
      name     = "AWSManagedRulesBotControlRuleSet"
      priority = 4

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesBotControlRuleSet"
          vendor_name = "AWS"

          rule_action_override {
            name = "CategorySocialMedia"
            action_to_use {
              count {}
            }
          }

          rule_action_override {
            name = "CategorySearchEngine"
            action_to_use {
              count {}
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "BotControlRuleSetMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  # AWS Managed Rules - PHP Application Protection
  rule {
    name     = "AWSManagedRulesPHPRuleSet"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesPHPRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PHPRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection Protection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Linux Operating System Protection
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 7

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "LinuxRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Livewire/Filament endpoints are chatty and need a separate budget.
  rule {
    name     = "RateLimitLivewire"
    priority = 8

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_livewire
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = "/livewire/"
            positional_constraint = "STARTS_WITH"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitLivewire"
      sampled_requests_enabled   = true
    }
  }

  # General rate limit excludes Livewire, static assets, and health probes.
  rule {
    name     = "RateLimitGeneral"
    priority = 9

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_general
        aggregate_key_type = "IP"

        scope_down_statement {
          not_statement {
            statement {
              or_statement {
                dynamic "statement" {
                  for_each = toset(concat(["/livewire/", "/build/", "/css/", "/js/", "/storage/"], var.rate_limit_excluded_path_prefixes))
                  content {
                    byte_match_statement {
                      search_string         = statement.value
                      positional_constraint = "STARTS_WITH"

                      field_to_match {
                        uri_path {}
                      }

                      text_transformation {
                        priority = 0
                        type     = "NONE"
                      }
                    }
                  }
                }

                dynamic "statement" {
                  for_each = toset(concat([var.health_check_path, "/health", "/favicon.ico"], var.rate_limit_excluded_exact_paths))
                  content {
                    byte_match_statement {
                      search_string         = statement.value
                      positional_constraint = "EXACTLY"

                      field_to_match {
                        uri_path {}
                      }

                      text_transformation {
                        priority = 0
                        type     = "NONE"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitGeneral"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-waf"
  })
}

# ========================================
# Application Load Balancer
# ========================================

locals {
  domain_starts_with_www = startswith(lower(var.domain_name), "www.")
}

resource "aws_lb" "main" {
  name               = "${var.app_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnets

  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = var.drop_invalid_header_fields

  access_logs {
    bucket  = var.alb_logs_bucket_name
    prefix  = "alb"
    enabled = var.enable_access_logs
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-alb"
  })
}

# Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.app_name}-${var.environment}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 5
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 5

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 24 hours
    enabled         = var.enable_stickiness
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-tg"
  })
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.common_tags
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  depends_on = [aws_lb_target_group.main]
  tags       = var.common_tags
}

# HTTPS Listener Rule - Redirect www to non-www
resource "aws_lb_listener_rule" "redirect_www" {
  count        = local.domain_starts_with_www ? 0 : 1
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      host        = var.domain_name
      port        = "443"
      protocol    = "HTTPS"
      path        = "/#{path}"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["www.${var.domain_name}"]
    }
  }

  tags = var.common_tags
}

# Attach each vanity domain certificate to the HTTPS listener (SNI)
resource "aws_lb_listener_certificate" "vanity" {
  for_each = { for vanity_domain in var.vanity_domains : vanity_domain.domain => vanity_domain }

  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value.certificate_arn
}

# Redirect vanity domain traffic to the configured target
resource "aws_lb_listener_rule" "vanity_redirect" {
  for_each = { for vanity_domain in var.vanity_domains : vanity_domain.domain => vanity_domain }

  listener_arn = aws_lb_listener.https.arn
  priority     = 10 + index(var.vanity_domains, each.value)

  action {
    type = "redirect"

    redirect {
      host        = each.value.redirect_host
      path        = each.value.redirect_path
      port        = "443"
      protocol    = "HTTPS"
      query       = ""
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = [each.value.domain, "*.${each.value.domain}"]
    }
  }

  tags = var.common_tags
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ========================================
# Optional CloudFront Distribution in Front of ALB
# ========================================

resource "aws_cloudfront_distribution" "app" {
  count = var.enable_cloudfront_app ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.cloudfront_app_price_class
  aliases         = var.cloudfront_app_aliases
  http_version    = "http2and3"

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-${aws_lb.main.name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id         = "alb-${aws_lb.main.name}"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # Managed-AllViewer
    compress                 = true
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset(["/build/*", "/css/filament/*", "/js/filament/*"])
    content {
      path_pattern           = ordered_cache_behavior.value
      target_origin_id       = "alb-${aws_lb.main.name}"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD", "OPTIONS"]
      cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
      compress               = true
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.cloudfront_app_certificate_arn != "" ? var.cloudfront_app_certificate_arn : null
    cloudfront_default_certificate = var.cloudfront_app_certificate_arn == ""
    ssl_support_method             = var.cloudfront_app_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.cloudfront_app_certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-app-cloudfront"
  })
}
