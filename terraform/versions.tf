terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # S3 backend for state management
  # Uses Terraform workspaces for environment isolation
  backend "s3" {
    bucket               = "laravel-terraform-state-bucket"
    key                  = "laravel/terraform.tfstate"
    workspace_key_prefix = "env"
    region               = "us-east-1"
    encrypt              = true
    # dynamodb_table       = "laravel-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
}
