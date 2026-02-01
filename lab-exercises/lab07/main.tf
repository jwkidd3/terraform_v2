terraform {
  required_version = ">= 1.9"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  # Using local backend for this lab
  # Remote state configuration is covered in Lab 6
}

provider "aws" {
  region = var.aws_region
}

variable "username" {
  description = "Your unique username"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters, lowercase letters and numbers only."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Local values for configuration
locals {
  name_prefix = "${var.username}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)  # Use only 2 AZs for simplicity
  
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    Project     = "RegistryModules"
    ManagedBy   = "Terraform"
    Lab         = "7"
  }
}

# VPC using community module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Enable NAT for private subnets
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization: single NAT gateway
  enable_vpn_gateway = false

  # Enable DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Type = "NetworkingFoundation"
  })
}

# Web server security group using community module
module "web_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 5.0"

  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.common_tags
}

# SSH security group using community module
module "ssh_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "~> 5.0"

  name        = "${local.name_prefix}-ssh-sg"
  description = "Security group for SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["10.0.0.0/16"]  # Only allow SSH from within VPC

  tags = local.common_tags
}

# Create EC2 instances using the security groups
resource "aws_instance" "web" {
  count = 2

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  subnet_id = module.vpc.private_subnets[count.index]
  vpc_security_group_ids = [
    module.web_security_group.security_group_id,
    module.ssh_security_group.security_group_id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Web Server ${count.index + 1} (${var.username})</h1>" > /var/www/html/index.html
    echo "<p>Server running in ${var.environment} environment</p>" >> /var/www/html/index.html
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
    Type = "WebServer"
  })
}

# Load balancer to distribute traffic
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.web_security_group.security_group_id]
  subnets           = module.vpc.public_subnets

  tags = merge(local.common_tags, {
    Type = "LoadBalancer"
  })
}

# Target group for load balancer
resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

# Attach instances to target group
resource "aws_lb_target_group_attachment" "web" {
  count = length(aws_instance.web)

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# Listener for load balancer
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# S3 bucket using community module
module "s3_logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name_prefix}-app-logs-${random_string.bucket_suffix.result}"

  # Basic bucket configuration
  force_destroy = true

  # Versioning
  versioning = {
    enabled = false
  }

  # Encryption disabled for simplicity in shared training environment

  tags = merge(local.common_tags, {
    Type = "ApplicationLogs"
  })
}

# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}