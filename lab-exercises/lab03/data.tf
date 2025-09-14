# data.tf - Advanced Data Sources for Dynamic Discovery

# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get all availability zones in current region
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Find default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get subnet details for each subnet
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Find the default security group
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}

# Get current AWS partition (useful for ARN construction)
data "aws_partition" "current" {}


# Get Route 53 hosted zone (if exists)
data "aws_route53_zone" "main" {
  count = var.security_config.ssl_certificate_arn != "" ? 1 : 0
  name  = "example.com"
  private_zone = false
}

# Find SSL certificate (if specified)
data "aws_acm_certificate" "main" {
  count  = var.security_config.ssl_certificate_arn != "" ? 1 : 0
  arn    = var.security_config.ssl_certificate_arn
  statuses = ["ISSUED"]
}