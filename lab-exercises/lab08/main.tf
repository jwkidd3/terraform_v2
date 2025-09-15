terraform {
  required_version = ">= 1.5"
  
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
  # In production, you would use remote state per environment
}

provider "aws" {
  region = "us-east-2"
}

# Local values for environment-specific logic
locals {
  name_prefix = "${var.username}-${var.environment}"
  
  # Environment-specific settings
  availability_zones = var.enable_high_availability ? slice(data.aws_availability_zones.available.names, 0, 2) : slice(data.aws_availability_zones.available.names, 0, 1)
    
  backup_retention = var.environment == "prod" ? 30 : (var.environment == "staging" ? 7 : 1)
  
  use_private_subnets = var.environment != "dev"
  
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    Project     = "MultiEnvironment"
    ManagedBy   = "Terraform"
    Lab         = "7"
  }
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

# VPC Module - environment-aware configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs = local.availability_zones
  
  # Environment-specific subnet configuration
  private_subnets = local.use_private_subnets ? [
    for i, az in local.availability_zones : "10.0.${i + 1}.0/24"
  ] : []
  
  public_subnets = [
    for i, az in local.availability_zones : "10.0.${i + 101}.0/24"
  ]

  # NAT Gateway only for non-dev environments
  enable_nat_gateway = local.use_private_subnets
  single_nat_gateway = var.environment != "prod"  # Multiple NAT gateways only in prod
  
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Security group with environment-specific rules
resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  description = "Security group for application servers"
  vpc_id      = module.vpc.vpc_id

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # SSH access (restricted in production)
  dynamic "ingress" {
    for_each = var.environment == "prod" ? [] : [1]
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# Launch Template for environment-specific configuration
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.app.id]
  
  # Use spot instances if configured
  dynamic "instance_market_options" {
    for_each = var.cost_optimization.use_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = var.cost_optimization.max_price
      }
    }
  }
  
  monitoring {
    enabled = var.enable_monitoring
  }
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    username    = var.username
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Type = "ApplicationServer"
    })
  }

  tags = local.common_tags
}

# Auto Scaling Group for resilience
resource "aws_autoscaling_group" "app" {
  name                = "${local.name_prefix}-asg"
  vpc_zone_identifier = local.use_private_subnets ? module.vpc.private_subnets : module.vpc.public_subnets
  target_group_arns   = var.enable_high_availability ? [aws_lb_target_group.app[0].arn] : []
  
  min_size         = 1
  max_size         = var.enable_high_availability ? var.instance_count * 2 : var.instance_count
  desired_capacity = var.instance_count
  
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  
  # Health checks
  health_check_type         = var.enable_high_availability ? "ELB" : "EC2"
  health_check_grace_period = 300
  
  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg"
    propagate_at_launch = false
  }
  
  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Load Balancer for high availability environments
resource "aws_lb" "app" {
  count = var.enable_high_availability ? 1 : 0
  
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = module.vpc.public_subnets

  tags = local.common_tags
}

resource "aws_lb_target_group" "app" {
  count = var.enable_high_availability ? 1 : 0
  
  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "app" {
  count = var.enable_high_availability ? 1 : 0
  
  load_balancer_arn = aws_lb.app[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
}