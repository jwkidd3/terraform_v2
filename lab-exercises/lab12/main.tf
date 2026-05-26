terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "REPLACE_WITH_YOUR_ORG"   # e.g., "user1-terraform-training"

    workspaces {
      name = "REPLACE_WITH_WORKSPACE_NAME"   # e.g., "vcs-lab12-user1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "${var.username}-${var.environment}"

  common_tags = {
    Owner       = var.username
    Environment = var.environment
    ManagedBy   = "TerraformCloud"
    Lab         = "12"
    Workflow    = "VCS-driven"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "demo" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    username    = var.username
    environment = var.environment
    app_version = var.app_version
  }))

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-demo"
    AppVersion = var.app_version
  })
}
