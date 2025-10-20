# ========================================
# VPC Configuration
# ========================================

# VPC Module (using public module)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(var.availability_zones, 0, 3) # Use only first 3 AZs
  private_subnets = [for k in range(3) : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k in range(3) : cidrsubnet(var.vpc_cidr, 4, k + 4)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.common_tags
}

# ========================================
# Security Groups
# ========================================

# ALB Security Group
module "alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.app_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-alb-sg"
  })
}

# ECS Security Group
module "ecs_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.app_name}-${var.environment}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-ecs-sg"
  })
}

# RDS Security Group
module "rds_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.app_name}-${var.environment}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.ecs_security_group.security_group_id
      description              = "Allow MySQL access from ECS tasks"
    },
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.vpn_security_group.security_group_id
      description              = "Allow MySQL access from VPN clients"
    }
  ]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-rds-sg"
  })
}

# Redis Security Group
module "redis_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.app_name}-${var.environment}-redis-sg"
  description = "Security group for Redis cluster"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "redis-tcp"
      source_security_group_id = module.ecs_security_group.security_group_id
    }
  ]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-redis-sg"
  })
}

# VPN Client Security Group
module "vpn_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.app_name}-${var.environment}-vpn-sg"
  description = "Security group for VPN clients"
  vpc_id      = module.vpc.vpc_id

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-vpn-sg"
  })
}

# VPC Endpoints Security Group
module "vpc_endpoints_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.app_name}-${var.environment}-vpc-endpoints-sg"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["https-443-tcp"]
  ingress_cidr_blocks = [var.vpc_cidr]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-vpc-endpoints-sg"
  })
}

# ========================================
# VPC Interface Endpoints
# ========================================

locals {
  interface_endpoint_tags = merge(var.common_tags, {
    TerraformComponent = "vpc-endpoints"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_id              = module.vpc.vpc_id
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [module.vpc_endpoints_security_group.security_group_id]
  private_dns_enabled = true

  tags = merge(local.interface_endpoint_tags, {
    Name = "${var.app_name}-${var.environment}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_id              = module.vpc.vpc_id
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [module.vpc_endpoints_security_group.security_group_id]
  private_dns_enabled = true

  tags = merge(local.interface_endpoint_tags, {
    Name = "${var.app_name}-${var.environment}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_id              = module.vpc.vpc_id
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [module.vpc_endpoints_security_group.security_group_id]
  private_dns_enabled = true

  tags = merge(local.interface_endpoint_tags, {
    Name = "${var.app_name}-${var.environment}-ec2messages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_api" {
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_id              = module.vpc.vpc_id
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [module.vpc_endpoints_security_group.security_group_id]
  private_dns_enabled = true

  tags = merge(local.interface_endpoint_tags, {
    Name = "${var.app_name}-${var.environment}-ecr-api-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_id              = module.vpc.vpc_id
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [module.vpc_endpoints_security_group.security_group_id]
  private_dns_enabled = true

  tags = merge(local.interface_endpoint_tags, {
    Name = "${var.app_name}-${var.environment}-ecr-dkr-endpoint"
  })
}

resource "aws_vpc_endpoint" "logs" {
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_id              = module.vpc.vpc_id
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [module.vpc_endpoints_security_group.security_group_id]
  private_dns_enabled = true

  tags = merge(local.interface_endpoint_tags, {
    Name = "${var.app_name}-${var.environment}-logs-endpoint"
  })
}

resource "aws_vpc_endpoint" "sqs" {
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_id              = module.vpc.vpc_id
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [module.vpc_endpoints_security_group.security_group_id]
  private_dns_enabled = true

  tags = merge(local.interface_endpoint_tags, {
    Name = "${var.app_name}-${var.environment}-sqs-endpoint"
  })
}

# ========================================
# VPC Gateway Endpoints
# ========================================

resource "aws_vpc_endpoint" "s3" {
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_id            = module.vpc.vpc_id
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = merge(var.common_tags, {
    Name               = "${var.app_name}-${var.environment}-s3-endpoint"
    TerraformComponent = "vpc-endpoints"
  })
}
