# Lab 3: Advanced Variables and Enterprise Patterns (45 minutes)

## Overview
This lab focuses on mastering advanced Terraform variable patterns including complex variable types, validation rules, sensitive data handling, and enterprise security patterns. You'll build a comprehensive multi-tier web application infrastructure using advanced variable techniques.

## Learning Objectives
By the end of this lab, you will be able to:
- Implement complex variable types (objects, maps, lists) with validation
- Handle sensitive variables and secure configuration patterns
- Use advanced data sources for dynamic resource discovery
- Implement enterprise tagging and cost allocation strategies
- Create reusable variable patterns for multi-environment deployments
- Implement security best practices with variables and data sources

## Prerequisites
- Completion of Lab 2
- Understanding of basic Terraform workflow and AWS services
- AWS Cloud9 environment with appropriate IAM permissions

## Lab Environment Setup

### Step 1: Environment Preparation
```bash
# Create and navigate to lab directory
cd ~/environment
mkdir -p terraform-training/lab03-advanced-variables
cd terraform-training/lab03-advanced-variables

# Set environment variables
export AWS_DEFAULT_REGION=us-east-2
export TF_VAR_username="user1"  # Replace with your assigned username

# Verify AWS CLI access
aws sts get-caller-identity
```

## Section 1: Advanced Variable Patterns (15 minutes)

### Step 1: Create Advanced Variable Definitions

Create the `variables.tf` file with advanced variable patterns:

```hcl
# variables.tf - Advanced Variable Definitions

# Basic validated variables
variable "username" {
  description = "Your unique username (for shared environment)"
  type        = string
  validation {
    condition     = length(var.username) > 2 && length(var.username) <= 20
    error_message = "Username must be between 3 and 20 characters."
  }
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.username))
    error_message = "Username must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Complex object variable for application configuration
variable "application_config" {
  description = "Application configuration settings"
  type = object({
    name         = string
    version      = string
    port         = number
    health_check = object({
      path     = string
      interval = number
      timeout  = number
    })
    scaling = object({
      min_size         = number
      max_size         = number
      desired_capacity = number
    })
  })
  validation {
    condition     = var.application_config.port >= 1024 && var.application_config.port <= 65535
    error_message = "Application port must be between 1024 and 65535."
  }
  validation {
    condition     = var.application_config.scaling.min_size <= var.application_config.scaling.desired_capacity && var.application_config.scaling.desired_capacity <= var.application_config.scaling.max_size
    error_message = "Scaling configuration: min_size <= desired_capacity <= max_size."
  }
}

# Complex map for instance configurations
variable "instance_types" {
  description = "Map of environment to instance configurations"
  type = map(object({
    instance_type = string
    volume_size   = number
    monitoring    = bool
  }))
  default = {
    dev = {
      instance_type = "t3.micro"
      volume_size   = 20
      monitoring    = false
    }
    staging = {
      instance_type = "t3.small"
      volume_size   = 30
      monitoring    = true
    }
    prod = {
      instance_type = "t3.medium"
      volume_size   = 50
      monitoring    = true
    }
  }
}

# Sensitive database configuration
variable "database_config" {
  description = "Database configuration with sensitive data"
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    allocated_storage = number
    username       = string
    password       = string
    backup_retention = number
    multi_az       = bool
  })
  sensitive = true
  validation {
    condition     = length(var.database_config.password) >= 12
    error_message = "Database password must be at least 12 characters long."
  }
  validation {
    condition     = can(regex("[A-Z]", var.database_config.password)) && can(regex("[a-z]", var.database_config.password)) && can(regex("[0-9]", var.database_config.password))
    error_message = "Database password must contain uppercase, lowercase, and numeric characters."
  }
}

# List of availability zones
variable "availability_zones" {
  description = "List of availability zones to deploy into"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.availability_zones) >= 2 || length(var.availability_zones) == 0
    error_message = "Either specify at least 2 availability zones or leave empty for auto-detection."
  }
}

# Enterprise tagging configuration
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Security configuration
variable "security_config" {
  description = "Security settings for the infrastructure"
  type = object({
    enable_encryption     = bool
    enable_logging       = bool
    allowed_cidr_blocks  = list(string)
    ssl_certificate_arn  = string
    backup_enabled       = bool
  })
  default = {
    enable_encryption    = false
    enable_logging      = true
    allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    ssl_certificate_arn = ""
    backup_enabled      = true
  }
  validation {
    condition = alltrue([
      for cidr in var.security_config.allowed_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid CIDR notation."
  }
}

# Cost allocation settings
variable "cost_allocation" {
  description = "Cost allocation and billing configuration"
  type = object({
    project_code   = string
    cost_center    = string
    billing_team   = string
    budget_alert   = number
  })
  validation {
    condition     = can(regex("^[A-Z]{3}-[0-9]{4}$", var.cost_allocation.project_code))
    error_message = "Project code must follow format: ABC-1234."
  }
}

# Key pair for EC2 instances
variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  default     = ""
  validation {
    condition     = var.key_pair_name == "" || length(var.key_pair_name) > 0
    error_message = "Key pair name must be empty or a valid key pair name."
  }
}
```

### Step 2: Create Complex Variable Values

Create the `terraform.tfvars` file with comprehensive configuration:

```hcl
# terraform.tfvars - Production-Ready Variable Values

# Basic configuration
username = "user1"  # Replace with your assigned username
environment  = "dev"

# Application configuration
application_config = {
  name    = "enterprise-web-app"
  version = "2.1.0"
  port    = 8080
  health_check = {
    path     = "/health"
    interval = 30
    timeout  = 5
  }
  scaling = {
    min_size         = 2
    max_size         = 10
    desired_capacity = 3
  }
}

# Database configuration (sensitive)
database_config = {
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  username          = "admin"
  password          = "SecurePassword123!"
  backup_retention  = 7
  multi_az          = false
}

# Security configuration
security_config = {
  enable_encryption    = true
  enable_logging      = true
  allowed_cidr_blocks = ["10.0.0.0/16", "172.16.0.0/12"]
  ssl_certificate_arn = ""
  backup_enabled      = true
}

# Enterprise tagging
tags = {
  Owner       = "DevOps Team"
  Project     = "Terraform Training"
  Environment = "Development"
  CostCenter  = "Engineering"
  Compliance  = "Required"
}

# Cost allocation
cost_allocation = {
  project_code = "TRF-2024"
  cost_center  = "Engineering"
  billing_team = "Platform Team"
  budget_alert = 100
}
```

## Section 2: Advanced Data Sources and Dynamic Discovery (15 minutes)

### Step 1: Create Comprehensive Data Sources

Create the `data.tf` file for dynamic resource discovery:

```hcl
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

# Find existing KMS key for encryption
data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}

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
```

### Step 2: Create Local Values for Complex Calculations

Create the `locals.tf` file for computed values:

```hcl
# locals.tf - Complex Calculations and Derived Values

locals {
  # Environment-specific configuration
  current_config = var.instance_types[var.environment]
  
  # Availability zones to use (either specified or auto-detected)
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
  
  # Common naming prefix
  name_prefix = "${var.username}-${var.environment}"
  
  # Enhanced tagging strategy
  common_tags = merge(var.tags, {
    Environment   = var.environment
    Owner         = var.username
    Application   = var.application_config.name
    Version       = var.application_config.version
    ManagedBy     = "Terraform"
    CreatedDate   = timestamp()
    ProjectCode   = var.cost_allocation.project_code
    CostCenter    = var.cost_allocation.cost_center
    BillingTeam   = var.cost_allocation.billing_team
    Region        = data.aws_region.current.name
    AccountId     = data.aws_caller_identity.current.account_id
  })
  
  # Security group rules configuration
  ingress_rules = {
    http = {
      port        = 80
      protocol    = "tcp"
      description = "HTTP access"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    https = {
      port        = 443
      protocol    = "tcp"
      description = "HTTPS access"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    app = {
      port        = var.application_config.port
      protocol    = "tcp"
      description = "Application port"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    ssh = {
      port        = 22
      protocol    = "tcp"
      description = "SSH access (restricted)"
      cidr_blocks = ["10.0.0.0/8"]
    }
  }
  
  # Database subnet group name
  db_subnet_group_name = "${local.name_prefix}-db-subnet-group"
  
  # User data script for web servers
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name    = var.application_config.name
    app_version = var.application_config.version
    app_port    = var.application_config.port
    environment = var.environment
    username    = var.username
  }))
  
  # Calculate costs and resource limits
  estimated_monthly_cost = {
    instances = length(local.azs) * (local.current_config.instance_type == "t3.micro" ? 8.5 : local.current_config.instance_type == "t3.small" ? 17 : 34)
    storage   = length(local.azs) * local.current_config.volume_size * 0.10
    database  = var.database_config.instance_class == "db.t3.micro" ? 15 : 30
  }
  
  # Resource naming patterns
  resource_names = {
    vpc_sg           = "${local.name_prefix}-vpc-sg"
    alb_sg           = "${local.name_prefix}-alb-sg"
    database_sg      = "${local.name_prefix}-db-sg"
    launch_template  = "${local.name_prefix}-lt"
    auto_scaling     = "${local.name_prefix}-asg"
    load_balancer    = "${local.name_prefix}-alb"
    target_group     = "${local.name_prefix}-tg"
    database         = "${replace(local.name_prefix, "-", "")}db"
  }
}
```

## Section 3: Enterprise Infrastructure Implementation (10 minutes)

### Step 1: Create Version and Provider Configuration

Create the `versions.tf` file:

```hcl
# versions.tf - Terraform and Provider Version Constraints

terraform {
  required_version = ">= 1.5"
  
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

# AWS Provider configuration
provider "aws" {
  region = "us-east-2"
  
  default_tags {
    tags = local.common_tags
  }
}
```

### Step 2: Create Main Infrastructure Configuration

Create the comprehensive `main.tf` file:

```hcl
# main.tf - Enterprise Infrastructure Configuration

# Random password for RDS (demonstration purposes)
resource "random_password" "db_password" {
  count   = var.database_config.password == "" ? 1 : 0
  length  = 16
  special = true
}

# Random suffix for S3 bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = local.resource_names.alb_sg
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = {
      http  = { port = 80, cidr = ["0.0.0.0/0"] }
      https = { port = 443, cidr = ["0.0.0.0/0"] }
    }
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr
      description = "${upper(ingress.key)} traffic"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.alb_sg
    Type = "LoadBalancer"
  })
}

# Web Server Security Group
resource "aws_security_group" "web" {
  name        = local.resource_names.vpc_sg
  description = "Security group for web servers"
  vpc_id      = data.aws_vpc.default.id

  # Dynamic ingress rules from local configuration
  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }
  
  # Allow traffic from ALB
  ingress {
    from_port       = var.application_config.port
    to_port         = var.application_config.port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.vpc_sg
    Type = "WebServer"
  })
}

# Database Security Group
resource "aws_security_group" "database" {
  name        = local.resource_names.database_sg
  description = "Security group for RDS database"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
    description     = "MySQL access from web servers"
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.database_sg
    Type = "Database"
  })
}

# Launch Template for Auto Scaling Group
resource "aws_launch_template" "web" {
  name_prefix   = "${local.resource_names.launch_template}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.current_config.instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  vpc_security_group_ids = [aws_security_group.web.id]
  
  user_data = local.user_data

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.current_config.volume_size
      volume_type           = "gp3"
      encrypted             = var.security_config.enable_encryption
      kms_key_id           = var.security_config.enable_encryption ? data.aws_kms_key.ebs.arn : null
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = local.current_config.monitoring
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-web"
      Type = "WebServer"
    })
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.launch_template
    Type = "LaunchTemplate"
  })
}

# S3 Bucket for Access Logs
resource "aws_s3_bucket" "logs" {
  bucket        = "${local.name_prefix}-access-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-access-logs"
    Type = "LogStorage"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption disabled for simplicity in shared training environment

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = local.resource_names.load_balancer
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = merge(local.common_tags, {
    Name = local.resource_names.load_balancer
    Type = "LoadBalancer"
  })
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "web" {
  name     = local.resource_names.target_group
  port     = var.application_config.port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = var.application_config.health_check.timeout
    interval            = var.application_config.health_check.interval
    path                = var.application_config.health_check.path
    matcher             = "200"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.target_group
    Type = "TargetGroup"
  })
}

# Load Balancer Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = local.common_tags
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = local.resource_names.auto_scaling
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.application_config.scaling.min_size
  max_size         = var.application_config.scaling.max_size
  desired_capacity = var.application_config.scaling.desired_capacity

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = local.resource_names.auto_scaling
    propagate_at_launch = true
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

# Database Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = local.db_subnet_group_name
  subnet_ids = data.aws_subnets.default.ids

  tags = merge(local.common_tags, {
    Name = local.db_subnet_group_name
    Type = "DatabaseSubnetGroup"
  })
}

# RDS Database Instance
resource "aws_db_instance" "main" {
  identifier = local.resource_names.database

  engine         = var.database_config.engine
  engine_version = var.database_config.engine_version
  instance_class = var.database_config.instance_class
  
  allocated_storage     = var.database_config.allocated_storage
  max_allocated_storage = var.database_config.allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = var.security_config.enable_encryption
  kms_key_id           = var.security_config.enable_encryption ? data.aws_kms_key.ebs.arn : null

  db_name  = "appdb"
  username = var.database_config.username
  password = var.database_config.password != "" ? var.database_config.password : random_password.db_password[0].result

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = var.database_config.backup_retention
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"
  
  multi_az               = var.database_config.multi_az
  publicly_accessible    = false
  
  skip_final_snapshot = true
  deletion_protection = false

  performance_insights_enabled = local.current_config.monitoring
  monitoring_interval         = local.current_config.monitoring ? 60 : 0
  
  enabled_cloudwatch_logs_exports = var.security_config.enable_logging ? ["error", "general", "slow"] : []

  tags = merge(local.common_tags, {
    Name = local.resource_names.database
    Type = "Database"
  })
}
```

### Step 3: Create User Data Script

Create the `user_data.sh` file for instance initialization:

```bash
#!/bin/bash
# user_data.sh - Advanced Instance Initialization Script

# Variables from template
APP_NAME="${app_name}"
APP_VERSION="${app_version}"
APP_PORT="${app_port}"
ENVIRONMENT="${environment}"
USERNAME="${username}"

# Update system
yum update -y

# Install packages
yum install -y \
    httpd \
    mysql \
    wget \
    curl \
    git \
    htop \
    awslogs

# Configure Apache
systemctl start httpd
systemctl enable httpd

# Create application directory
mkdir -p /var/www/html/app

# Create enhanced web application
cat << EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$APP_NAME - $ENVIRONMENT</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .info { background: #e7f3ff; padding: 10px; border-radius: 4px; margin: 10px 0; }
        .success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .warning { background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$APP_NAME</h1>
        <div class="info success">
            <strong>Application Status:</strong> Running Successfully
        </div>
        <div class="info">
            <strong>Version:</strong> $APP_VERSION<br>
            <strong>Environment:</strong> $ENVIRONMENT<br>
            <strong>Owner:</strong> $USERNAME<br>
            <strong>Port:</strong> $APP_PORT<br>
            <strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)<br>
            <strong>Instance Type:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-type)<br>
            <strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)<br>
            <strong>Private IP:</strong> $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)<br>
            <strong>Public IP:</strong> $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
        </div>
        <div class="info warning">
            <strong>Note:</strong> This is a Terraform training environment
        </div>
    </div>
</body>
</html>
EOF

# Create health check endpoint
cat << EOF > /var/www/html/health
{
    "status": "healthy",
    "application": "$APP_NAME",
    "version": "$APP_VERSION",
    "environment": "$ENVIRONMENT",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Configure application port (if not 80)
if [ "$APP_PORT" != "80" ]; then
    echo "Listen $APP_PORT" >> /etc/httpd/conf/httpd.conf
    cat << EOF >> /etc/httpd/conf/httpd.conf

<VirtualHost *:$APP_PORT>
    DocumentRoot /var/www/html
    ServerName localhost
</VirtualHost>
EOF
    systemctl restart httpd
fi

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat << EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "metrics": {
        "namespace": "$APP_NAME",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "$APP_NAME/httpd/access",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "$APP_NAME/httpd/error",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Create application startup script
cat << EOF > /etc/systemd/system/app-monitor.service
[Unit]
Description=Application Health Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/watch -n 30 'curl -f http://localhost/health || systemctl restart httpd'
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app-monitor
systemctl start app-monitor

# Final status check
systemctl status httpd
systemctl status amazon-cloudwatch-agent
systemctl status app-monitor

echo "Instance initialization completed successfully!" >> /var/log/user-data.log
```

## Section 4: Advanced Outputs and Verification (5 minutes)

### Step 1: Create Comprehensive Outputs

Create the `outputs.tf` file:

```hcl
# outputs.tf - Comprehensive Infrastructure Outputs

# Infrastructure Information
output "environment_info" {
  description = "Environment and deployment information"
  value = {
    username        = var.username
    environment     = var.environment
    aws_region      = data.aws_region.current.name
    aws_account_id  = data.aws_caller_identity.current.account_id
    deployment_time = timestamp()
  }
}

# Networking Information
output "networking" {
  description = "Network configuration details"
  value = {
    vpc_id             = data.aws_vpc.default.id
    vpc_cidr           = data.aws_vpc.default.cidr_block
    availability_zones = local.azs
    subnet_ids         = data.aws_subnets.default.ids
    subnet_details     = { for k, v in data.aws_subnet.default : k => {
        id                = v.id
        cidr_block       = v.cidr_block
        availability_zone = v.availability_zone
      }
    }
  }
}

# Security Group Information
output "security_groups" {
  description = "Security group details"
  value = {
    alb_sg = {
      id   = aws_security_group.alb.id
      name = aws_security_group.alb.name
    }
    web_sg = {
      id   = aws_security_group.web.id
      name = aws_security_group.web.name
    }
    db_sg = {
      id   = aws_security_group.database.id
      name = aws_security_group.database.name
    }
  }
}

# Load Balancer Information
output "load_balancer" {
  description = "Application Load Balancer details"
  value = {
    dns_name    = aws_lb.main.dns_name
    zone_id     = aws_lb.main.zone_id
    arn         = aws_lb.main.arn
    hosted_zone = aws_lb.main.canonical_hosted_zone_id
  }
}

# Auto Scaling Information
output "auto_scaling" {
  description = "Auto Scaling Group configuration"
  value = {
    name             = aws_autoscaling_group.web.name
    arn              = aws_autoscaling_group.web.arn
    min_size         = aws_autoscaling_group.web.min_size
    max_size         = aws_autoscaling_group.web.max_size
    desired_capacity = aws_autoscaling_group.web.desired_capacity
  }
}

# Database Information (sensitive)
output "database" {
  description = "RDS database configuration"
  value = {
    endpoint              = aws_db_instance.main.endpoint
    port                 = aws_db_instance.main.port
    database_name        = aws_db_instance.main.db_name
    username             = aws_db_instance.main.username
    engine               = aws_db_instance.main.engine
    engine_version       = aws_db_instance.main.engine_version
    instance_class       = aws_db_instance.main.instance_class
    allocated_storage    = aws_db_instance.main.allocated_storage
    backup_retention     = aws_db_instance.main.backup_retention_period
  }
  sensitive = true
}

# Application URLs
output "application_urls" {
  description = "URLs to access the application"
  value = {
    load_balancer_url = "http://${aws_lb.main.dns_name}"
    health_check_url  = "http://${aws_lb.main.dns_name}/health"
    application_port  = var.application_config.port
  }
}

# Resource Naming
output "resource_names" {
  description = "Generated resource names for reference"
  value = local.resource_names
}

# Cost Estimation
output "cost_estimation" {
  description = "Estimated monthly costs (USD)"
  value = {
    instances_cost = local.estimated_monthly_cost.instances
    storage_cost   = local.estimated_monthly_cost.storage
    database_cost  = local.estimated_monthly_cost.database
    total_estimate = local.estimated_monthly_cost.instances + local.estimated_monthly_cost.storage + local.estimated_monthly_cost.database
    note          = "Costs are estimates and may vary based on usage patterns"
  }
}

# Tagging Information
output "tagging_strategy" {
  description = "Applied tagging strategy"
  value = {
    common_tags    = local.common_tags
    cost_allocation = var.cost_allocation
    compliance_tags = {
      project_code = var.cost_allocation.project_code
      environment  = var.environment
      managed_by   = "Terraform"
    }
  }
}

# Variable Validation Summary
output "configuration_summary" {
  description = "Summary of applied configuration"
  value = {
    application_config = {
      name    = var.application_config.name
      version = var.application_config.version
      port    = var.application_config.port
      scaling = var.application_config.scaling
    }
    instance_config = local.current_config
    security_config = {
      encryption_enabled = var.security_config.enable_encryption
      logging_enabled    = var.security_config.enable_logging
      backup_enabled     = var.security_config.backup_enabled
    }
  }
}
```

## Section 5: Deploy and Validate Enterprise Infrastructure (10 minutes)

### Step 1: Initialize and Plan

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Plan deployment
terraform plan -out=tfplan

# Review the plan
terraform show tfplan
```

### Step 2: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply tfplan

# View all outputs
terraform output

# View specific outputs
terraform output application_urls
terraform output cost_estimation
terraform output environment_info
```

### Step 3: Validate and Test

```bash
# Test application health
ALB_URL=$(terraform output -json application_urls | jq -r '.load_balancer_url')
echo "Testing application at: $ALB_URL"
curl -s $ALB_URL

# Test health check endpoint
HEALTH_URL=$(terraform output -json application_urls | jq -r '.health_check_url')
echo "Testing health check at: $HEALTH_URL"
curl -s $HEALTH_URL

# Check Auto Scaling Group instances
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $(terraform output -json auto_scaling | jq -r '.name')

# Check RDS instance status
aws rds describe-db-instances --db-instance-identifier $(terraform output -json resource_names | jq -r '.database')
```

### Step 4: Variable Experimentation

```bash
# Modify terraform.tfvars to test different configurations
# Try changing:
# - environment = "staging"
# - application_config.scaling.desired_capacity = 4
# - security_config.enable_logging = false

# Plan the changes
terraform plan

# Apply if desired
# terraform apply
```

## Verification and Testing

### Infrastructure Validation Checklist
- [ ] All security groups have proper ingress/egress rules
- [ ] Load balancer is accessible from internet
- [ ] Auto Scaling Group has correct instance count
- [ ] RDS database is properly secured in private subnets
- [ ] S3 bucket is configured for shared environment
- [ ] All resources are properly tagged
- [ ] CloudWatch monitoring is configured
- [ ] Health checks are passing

### Security Validation
- [ ] Database is not publicly accessible
- [ ] Security groups follow least privilege principle
- [ ] Encryption is enabled where specified
- [ ] S3 bucket blocks public access
- [ ] Instance metadata requires tokens

## Lab Completion Checklist
- [ ] Created advanced variable definitions with validation
- [ ] Implemented complex variable types (objects, maps, lists)
- [ ] Used sensitive variables for database configuration
- [ ] Created comprehensive data sources for dynamic discovery
- [ ] Built multi-tier architecture with load balancer, auto scaling, and database
- [ ] Implemented enterprise tagging and cost allocation
- [ ] Created detailed outputs for infrastructure management
- [ ] Tested variable validation and security configurations
- [ ] Validated complete infrastructure deployment

## Key Takeaways

### Advanced Variable Patterns Mastered:
1. **Complex Variable Types**: Objects, maps, and lists with nested structures
2. **Variable Validation**: Custom validation rules for business logic
3. **Sensitive Variables**: Proper handling of secrets and sensitive data
4. **Variable Dependencies**: Using variables across different resource configurations
5. **Dynamic Configuration**: Environment-specific configurations using maps

### Enterprise Patterns Implemented:
1. **Multi-tier Architecture**: Load balancer, web servers, database
2. **Security Best Practices**: Least privilege, encryption, private networking
3. **Scalability Patterns**: Auto Scaling Groups with health checks
4. **Monitoring Integration**: CloudWatch metrics and logging
5. **Cost Management**: Resource tagging and cost estimation
6. **Compliance Features**: Audit logging and encryption standards

### Production-Ready Features:
1. **High Availability**: Multi-AZ deployment
2. **Security Hardening**: Security groups, encryption, private access
3. **Monitoring**: CloudWatch integration and health checks
4. **Backup Strategy**: Database backups and S3 versioning
5. **Cost Control**: Resource tagging and budget tracking

## Next Steps

In Lab 4, you'll learn:
- Resource dependencies and lifecycle management
- Advanced count and for_each patterns
- Complex resource relationships
- State management strategies

## Additional Resources

- [Terraform Variable Documentation](https://developer.hashicorp.com/terraform/language/values/variables)
- [AWS Provider Data Sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources)
- [Variable Validation Examples](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions)
- [Enterprise Tagging Strategies](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)

## Clean Up

```bash
# When ready to clean up resources
terraform destroy

# Confirm destruction
# Type 'yes' when prompted
```

**Congratulations! You've mastered advanced variable patterns and enterprise infrastructure deployment with Terraform!**