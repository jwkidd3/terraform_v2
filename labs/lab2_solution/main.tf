# Lab 2: Variables and Data Sources - Complete Solution
# main.tf - Main configuration with all resources

# ===========================================
# TERRAFORM CONFIGURATION
# ===========================================

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  # Local backend with username-specific state file
  backend "local" {
    path = "terraform.tfstate"
  }
}

# ===========================================
# PROVIDERS
# ===========================================

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = merge(
      var.common_tags,
      {
        Username    = var.username
        Environment = var.environment
        Lab         = "2"
      }
    )
  }
}

provider "random" {}

# ===========================================
# DATA SOURCES
# ===========================================

# Get current AWS account details
data "aws_caller_identity" "current" {}

# Get current region
data "aws_region" "current" {}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get latest Amazon Linux 2 AMI
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
    name   = "root-device-type"
    values = ["ebs"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Get default VPC (if not creating custom)
data "aws_vpc" "default" {
  count   = var.create_vpc ? 0 : 1
  default = true
}

# Get default subnets (if not creating custom)
data "aws_subnets" "default" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# ===========================================
# LOCAL VALUES
# ===========================================

locals {
  # Compute resource name prefix
  name_prefix = "${var.username}-${var.project_name}-${var.environment}"
  
  # Select instance type based on environment
  instance_type = lookup(var.instance_types, var.environment, "t2.micro")
  
  # Determine VPC and subnet IDs
  vpc_id = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.default[0].id
  
  subnet_ids = var.create_vpc ? aws_subnet.main[*].id : tolist(data.aws_subnets.default[0].ids)
  
  # Generate unique bucket name
  bucket_name = "${var.username}-${var.project_name}-${random_id.bucket_suffix.hex}"
  
  # Compute total instance count across all AZs
  total_instances = var.instance_count * length(var.availability_zones)
  
  # Enhanced tags with computed values
  resource_tags = merge(
    var.common_tags,
    {
      Username    = var.username
      Environment = var.environment
      Project     = var.project_name
      Region      = data.aws_region.current.name
      AccountId   = data.aws_caller_identity.current.account_id
      CreatedBy   = "terraform-lab2"
      Timestamp   = timestamp()
    }
  )
}

# ===========================================
# RANDOM RESOURCES
# ===========================================

# Random ID for unique naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Random password for demonstration
resource "random_password" "db" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Random pet name for fun naming
resource "random_pet" "server" {
  length    = 2
  separator = "-"
}

# ===========================================
# NETWORKING RESOURCES (OPTIONAL)
# ===========================================

# VPC
resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0
  
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = merge(
    local.resource_tags,
    {
      Name = "${local.name_prefix}-vpc"
      Type = "VPC"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count = var.create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  tags = merge(
    local.resource_tags,
    {
      Name = "${local.name_prefix}-igw"
      Type = "InternetGateway"
    }
  )
}

# Subnets
resource "aws_subnet" "main" {
  count = var.create_vpc ? length(var.subnet_cidrs) : 0
  
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true
  
  tags = merge(
    local.resource_tags,
    {
      Name = "${local.name_prefix}-subnet-${count.index + 1}"
      Type = "PublicSubnet"
      AZ   = var.availability_zones[count.index % length(var.availability_zones)]
    }
  )
}

# Route Table
resource "aws_route_table" "main" {
  count = var.create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
  
  tags = merge(
    local.resource_tags,
    {
      Name = "${local.name_prefix}-rt"
      Type = "RouteTable"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "main" {
  count = var.create_vpc ? length(aws_subnet.main) : 0
  
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main[0].id
}

# ===========================================
# SECURITY GROUP
# ===========================================

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web servers in Lab 2"
  vpc_id      = local.vpc_id
  
  # HTTP ingress
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS ingress
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # SSH ingress (restricted to VPC CIDR)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.create_vpc ? var.vpc_cidr : "10.0.0.0/8"]
  }
  
  # All egress
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    local.resource_tags,
    {
      Name = "${local.name_prefix}-web-sg"
      Type = "SecurityGroup"
    }
  )
}

# ===========================================
# EC2 INSTANCES
# ===========================================

resource "aws_instance" "web" {
  count = var.instance_count
  
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = local.subnet_ids[count.index % length(local.subnet_ids)]
  monitoring             = var.enable_monitoring
  
  # User data script to install web server
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    instance_name = "${local.name_prefix}-${count.index + 1}"
    environment   = var.environment
    username      = var.username
    pet_name      = random_pet.server.id
  }))
  
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
    
    tags = merge(
      local.resource_tags,
      {
        Name = "${local.name_prefix}-root-volume-${count.index + 1}"
        Type = "RootVolume"
      }
    )
  }
  
  tags = merge(
    local.resource_tags,
    {
      Name       = "${local.name_prefix}-instance-${count.index + 1}"
      Type       = "WebServer"
      ServerName = "${random_pet.server.id}-${count.index + 1}"
    }
  )
  
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ami]  # Ignore AMI changes after creation
  }
}

# ===========================================
# S3 BUCKET FOR DEMONSTRATION
# ===========================================

resource "aws_s3_bucket" "data" {
  bucket        = local.bucket_name
  force_destroy = true  # Allow destruction even with objects
  
  tags = merge(
    local.resource_tags,
    {
      Name = local.bucket_name
      Type = "DataBucket"
    }
  )
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload a sample file to S3
resource "aws_s3_object" "sample" {
  bucket = aws_s3_bucket.data.id
  key    = "lab2/sample-data.json"
  
  content = jsonencode({
    username    = var.username
    environment = var.environment
    timestamp   = timestamp()
    lab         = "2"
    random_pet  = random_pet.server.id
    instances   = var.instance_count
  })
  
  content_type = "application/json"
  
  tags = local.resource_tags
}

# ===========================================
# ELASTIC IP (OPTIONAL DEMONSTRATION)
# ===========================================

resource "aws_eip" "web" {
  count = var.environment == "prod" ? min(var.instance_count, 1) : 0
  
  domain   = "vpc"
  instance = aws_instance.web[count.index].id
  
  tags = merge(
    local.resource_tags,
    {
      Name = "${local.name_prefix}-eip-${count.index + 1}"
      Type = "ElasticIP"
    }
  )
  
  depends_on = [aws_internet_gateway.main]
}