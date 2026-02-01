terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use the module to create a development application
module "dev_blog" {
  source = "./modules/web-application"

  username          = var.username
  app_name          = "my-blog"
  environment       = "dev"
  instance_type     = "t3.micro"
  enable_monitoring = true
}

# Use the same module to create a different application
module "staging_portfolio" {
  source = "./modules/web-application"

  username          = var.username
  app_name          = "portfolio"
  environment       = "staging"
  instance_type     = "t3.small"
  enable_monitoring = false
}
