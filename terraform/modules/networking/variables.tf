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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "db_port" {
  description = "Database port for security group rules"
  type        = number
  default     = 3306
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all private subnets. Set false for one NAT gateway per AZ."
  type        = bool
  default     = true
}

variable "enable_vpc_interface_endpoints" {
  description = "Create VPC interface endpoints for private AWS service access"
  type        = bool
  default     = true
}

variable "enabled_vpc_interface_endpoints" {
  description = "AWS service endpoint short names to create when enable_vpc_interface_endpoints is true"
  type        = list(string)
  default     = ["ssm", "ssmmessages", "ec2messages", "ecr.api", "ecr.dkr", "logs", "sqs"]
}

variable "rds_additional_ingress_cidrs" {
  description = "Additional CIDR blocks allowed to connect to RDS/Aurora"
  type        = list(string)
  default     = []
}

variable "rds_additional_ingress_security_group_ids" {
  description = "Additional security group IDs allowed to connect to RDS/Aurora"
  type        = list(string)
  default     = []
}
