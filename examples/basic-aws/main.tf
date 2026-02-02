# Basic AWS Example - 3 Resources
# EC2 Instance, Security Group, and S3 Bucket

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

variable "username" {
  description = "Your unique username"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 1. Security Group
resource "aws_security_group" "web" {
  name        = "${var.username}-example-web-sg"
  description = "Allow HTTP inbound traffic"

  ingress {
    description = "HTTP"
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

  tags = {
    Name  = "${var.username}-example-web-sg"
    Owner = var.username
  }
}

# 2. EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from ${var.username}</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name  = "${var.username}-example-web-server"
    Owner = var.username
  }
}

# 3. S3 Bucket
resource "aws_s3_bucket" "data" {
  bucket        = "${var.username}-example-data-bucket"
  force_destroy = true

  tags = {
    Name  = "${var.username}-example-data"
    Owner = var.username
  }
}
