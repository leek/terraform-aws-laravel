# ========================================
# VPC Configuration
# ========================================

# VPC Module (using public module)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(var.availability_zones, 0, 3)  # Use only first 3 AZs
  private_subnets = [for k in range(3) : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k in range(3) : cidrsubnet(var.vpc_cidr, 4, k + 4)]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true

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