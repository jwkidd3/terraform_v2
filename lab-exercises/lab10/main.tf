terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "REPLACE_WITH_YOUR_ORG" # the exact org name you create in Exercise 10.1, e.g. "user1-terraform-training" (or "...-jd" if you added a suffix)

    workspaces {
      name = "REPLACE_WITH_WORKSPACE_NAME" # e.g., "user1-terraform-cloud-lab10"
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
    Lab         = "10"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_security_group" "demo" {
  name        = "${local.name_prefix}-demo-sg"
  description = "Allow HTTP for Lab 10 demo"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-demo-sg"
  })
}

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.demo.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Terraform Cloud Demo - ${var.username}</h1>" > /var/www/html/index.html
    echo "<p>Managed by Terraform Cloud</p>" >> /var/www/html/index.html
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-demo-instance"
  })
}
