# versions.tf - Provider and version constraints

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = var.project_name
      Owner         = var.username
      ManagedBy     = "Terraform"
      CostCenter    = "Training"
      CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
    }
  }
}

provider "random" {
  # Configuration options
}