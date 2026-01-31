# versions.tf - Terraform and Provider Version Constraints

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = var.username
      ManagedBy   = "Terraform"
      Project     = var.application_config.name
    }
  }
}