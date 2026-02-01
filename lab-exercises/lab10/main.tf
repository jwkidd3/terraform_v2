terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform Cloud backend configuration will be added during lab
  # Students create a new directory and build configuration from README.md
}

provider "aws" {
  region = var.aws_region
}

# This is a placeholder file.
# Lab 10 instructs students to create a new directory (~/environment/terraform-lab10)
# and build the full configuration from the README instructions.
