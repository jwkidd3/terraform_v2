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

    # Using `tags` (not `name`) is what lets one configuration target
    # multiple workspaces. Every workspace tagged "lab11" becomes
    # selectable via `terraform workspace select`.
    workspaces {
      tags = ["lab11"]
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.username}-${var.environment}-app-sg"
  description = "Lab 11 ${var.environment} workspace SG"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.username}-${var.environment}-app-sg"
    Environment = var.environment
    Owner       = var.username
    Lab         = "11"
  }
}

resource "aws_instance" "app" {
  count = var.instance_count

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = {
    Name        = "${var.username}-${var.environment}-instance-${count.index + 1}"
    Environment = var.environment
    Owner       = var.username
    ManagedBy   = "TerraformCloud"
    Lab         = "11"
  }
}
