# Get latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Bastion Security Group
resource "aws_security_group" "bastion" {
  name_prefix = "${var.app_name}-${var.environment}-bastion-"
  description = "Security group for bastion host with SSH access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH access from allowed CIDR blocks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for package updates and application access"
  }

  tags = merge(var.tags, {
    Name = "${var.app_name}-${var.environment}-bastion-sg"
  })
}

# IAM Role for Bastion
resource "aws_iam_role" "bastion" {
  name = "${var.app_name}-${var.environment}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for accessing Secrets Manager and KMS
resource "aws_iam_role_policy" "bastion_secrets" {
  name = "${var.app_name}-${var.environment}-bastion-secrets-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.rds_master_password_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.rds_kms_key_arn
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.app_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = var.tags
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  monitoring                  = var.enable_detailed_monitoring
  ebs_optimized               = var.ebs_optimized

  iam_instance_profile = aws_iam_instance_profile.bastion.name

  # Configure IMDSv2 (Instance Metadata Service Version 2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Require IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Encrypt root block device
  root_block_device {
    encrypted  = var.root_block_device_encrypted
    kms_key_id = var.root_block_device_kms_key_id != "" ? var.root_block_device_kms_key_id : null
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    install_mysql_client           = var.install_mysql_client
    install_redis_client           = var.install_redis_client
    rds_endpoint                   = var.rds_endpoint
    rds_master_username            = var.rds_master_username
    rds_master_password_secret_arn = var.rds_master_password_secret_arn
    rds_database_name              = var.rds_database_name
    app_db_username                = var.app_db_username
    app_db_password                = var.app_db_password
    db_reporting_password          = var.db_reporting_password
    aws_region                     = var.aws_region
    setup_mysql_user               = var.rds_endpoint != "" && var.app_db_username != ""
  }))

  tags = merge(var.tags, {
    Name = "${var.app_name}-${var.environment}-bastion"
  })
}
