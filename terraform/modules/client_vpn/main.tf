# ========================================
# CloudWatch Log Group (conditional)
# ========================================

resource "aws_cloudwatch_log_group" "vpn_connection_logs" {
  count             = var.connection_log_enabled ? 1 : 0
  name              = var.cloudwatch_log_group
  retention_in_days = 30
  kms_key_id        = var.cloudwatch_logs_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${var.name}-connection-logs"
  })
}

# ========================================
# CloudWatch Log Stream (conditional)
# ========================================

resource "aws_cloudwatch_log_stream" "vpn_connection_logs" {
  count          = var.connection_log_enabled ? 1 : 0
  name           = var.cloudwatch_log_stream
  log_group_name = aws_cloudwatch_log_group.vpn_connection_logs[0].name
}

# ========================================
# AWS Client VPN Endpoint
# ========================================

resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = var.description
  server_certificate_arn = var.server_certificate_arn
  client_cidr_block      = var.client_cidr_block
  dns_servers            = var.dns_servers
  split_tunnel           = var.split_tunnel
  vpn_port               = var.vpn_port
  transport_protocol     = var.transport_protocol
  session_timeout_hours  = var.session_timeout_hours

  authentication_options {
    type                           = "federated-authentication"
    saml_provider_arn              = var.saml_provider_arn
    self_service_saml_provider_arn = var.self_service_saml_provider_arn
  }

  connection_log_options {
    enabled               = var.connection_log_enabled
    cloudwatch_log_group  = var.connection_log_enabled ? aws_cloudwatch_log_group.vpn_connection_logs[0].name : null
    cloudwatch_log_stream = var.connection_log_enabled ? var.cloudwatch_log_stream : null
  }

  client_connect_options {
    enabled = var.client_connect_enabled
  }

  client_login_banner_options {
    enabled     = var.login_banner_enabled
    banner_text = var.login_banner_enabled ? var.login_banner_text : null
  }

  vpc_id             = var.vpc_id
  security_group_ids = var.security_group_ids

  tags = merge(var.common_tags, {
    Name = var.name
  })

  depends_on = [
    aws_cloudwatch_log_stream.vpn_connection_logs
  ]
}

# ========================================
# VPC Association
# ========================================

resource "aws_ec2_client_vpn_network_association" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = var.target_subnet_id
}

# ========================================
# Authorization Rules
# ========================================

resource "aws_ec2_client_vpn_authorization_rule" "vpc_access" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
  description            = "Allow access to VPC"
}

resource "aws_ec2_client_vpn_authorization_rule" "additional_cidrs" {
  for_each = toset(var.additional_authorized_cidrs)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = each.value
  authorize_all_groups   = true
  description            = "Allow access to ${each.value}"
}

# ========================================
# Route
# ========================================
# Note: The VPC route is automatically created by AWS when the network
# association is established, so we don't need to explicitly create it.