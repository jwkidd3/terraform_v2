# Lab 9: VPC Networking and 2-Tier Architecture
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 2
**Environment:** AWS Cloud9

---

## Learning Objectives
By the end of this lab, you will be able to:
- Design and implement a production-ready VPC with public and private subnets
- Configure advanced routing, a NAT Gateway, and Internet connectivity
- Deploy a 2-tier application architecture across availability zones
- Implement proper security group rules for network segmentation
- Configure an Application Load Balancer with health checks and target groups

---

## Prerequisites
- Completion of Labs 1-8
- Understanding of networking concepts (CIDR, subnets, routing)
- Knowledge of AWS availability zones and regions

---

## Lab Setup

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## Exercise 9.1: Design 2-Tier VPC Architecture (20 minutes)

### Step 1: Navigate to Lab Directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab09
```

### Step 2: Create Production-Ready VPC Infrastructure
Let's build a comprehensive VPC that supports a 2-tier application with public subnets (for the ALB and NAT Gateway) and private subnets (for the web/application servers).

**variables.tf:**
```hcl
variable "username" {
  description = "Your unique username"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters, lowercase letters and numbers only."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}
```

**terraform.tfvars:**
```hcl
username    = "user1"      # Replace with your username
environment = "development"
aws_region  = "us-east-1"  # Set to your AWS region
```

**main.tf:**
```hcl
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

# Data sources for dynamic resource selection
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

# Local values for consistent configuration
locals {
  name_prefix = "${var.username}-${var.environment}"
  vpc_cidr    = "10.0.0.0/16"

  # Calculate subnet CIDRs dynamically
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Owner       = var.username
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "VPC-Lab-9"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
    Type = "MainVPC"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public Subnets (for load balancers, NAT gateways)
resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "PublicSubnet"
    Tier = "Public"
    AZ   = local.availability_zones[count.index]
  })
}

# Private Subnets (for application servers)
resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "PrivateSubnet"
    Tier = "Application"
    AZ   = local.availability_zones[count.index]
  })
}


# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip"
    Type = "NATGatewayEIP"
  })
}

# Single NAT Gateway (cost optimization)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat"
    Type = "NATGateway"
  })
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Type = "PublicRouteTable"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt"
    Type = "PrivateRouteTable"
  })
}


# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(local.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(local.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}



# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
    Type = "LoadBalancerSecurityGroup"
  })
}


# Security Group for Web Servers
resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-web-"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }


  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
    Type = "WebServerSecurityGroup"
  })
}


# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
    Type = "ApplicationLoadBalancer"
  })
}

# Target Group for Web Servers
resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health.html"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  # Give instances time to start up
  deregistration_delay = 60

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-tg"
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

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-listener"
  })
}


# Web Servers in Private Subnets
resource "aws_instance" "web" {
  count = length(local.private_subnets)

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/user_data_web.sh", {
    server_id   = count.index + 1
    username    = var.username
    environment = var.environment
  }))

  # Ensure NAT Gateway route is ready before instances start
  depends_on = [aws_route_table_association.private]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
    Type = "WebServer"
    Tier = "Application"
    AZ   = local.availability_zones[count.index]
  })
}

# Register web servers with target group
resource "aws_lb_target_group_attachment" "web" {
  count = length(aws_instance.web)

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
```

---

## Exercise 9.2: Review Web Server User Data Script

The lab includes a **user_data_web.sh** script that configures the web servers:

```bash
#!/bin/bash
# Simplified user data script for faster startup

# Create health check endpoint FIRST (before any package operations)
mkdir -p /var/www/html
echo "OK" > /var/www/html/health.html

# Install and start Apache (skip yum update for faster startup)
yum install -y httpd

# Start Apache immediately
systemctl start httpd
systemctl enable httpd

# Create simple HTML page
cat <<'HTMLEOF' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Web Server ${server_id}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; max-width: 600px; margin: auto; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 15px; }
        .info { background: #ecf0f1; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .server { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>2-Tier VPC Application</h1>
        <p>Server <span class="server">${server_id}</span> | Owner: ${username}</p>

        <div class="info">
            <h3>Server Details</h3>
            <p><strong>Environment:</strong> ${environment}</p>
            <p><strong>Server ID:</strong> ${server_id}</p>
            <p><strong>Subnet:</strong> Private Application Subnet</p>
        </div>

        <div class="info">
            <h3>Architecture</h3>
            <ul>
                <li>Multi-AZ deployment</li>
                <li>Private subnets for web servers</li>
                <li>NAT Gateway for outbound access</li>
                <li>ALB with health checks</li>
            </ul>
        </div>
    </div>
</body>
</html>
HTMLEOF

# Set permissions
chmod 644 /var/www/html/index.html
chmod 644 /var/www/html/health.html
```

> **Key Design Decisions:**
> - Health check file created first, before any package installation
> - Skips `yum update` for faster startup (httpd install is sufficient)
> - Simple HTML page without PHP dependencies
> - Instances depend on NAT Gateway route being ready

---

## Exercise 9.3: Create Outputs and Deploy (10 minutes)

### Step 1: Create Outputs
Create **outputs.tf**:

```hcl
output "vpc_info" {
  description = "VPC configuration details"
  value = {
    vpc_id             = aws_vpc.main.id
    vpc_cidr           = aws_vpc.main.cidr_block
    availability_zones = local.availability_zones
    public_subnet_ids  = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id
  }
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "URL to access the web application"
  value       = "http://${aws_lb.main.dns_name}"
}


output "web_server_private_ips" {
  description = "Private IP addresses of web servers"
  value       = aws_instance.web[*].private_ip
}

output "security_groups" {
  description = "Security group IDs for different tiers"
  value = {
    alb_security_group = aws_security_group.alb.id
    web_security_group = aws_security_group.web.id
  }
}

output "nat_gateway_ip" {
  description = "Public IP address of NAT Gateway"
  value       = aws_eip.nat.public_ip
}
```

### Step 2: Deploy and Test the Infrastructure
```bash
# Initialize and deploy
terraform init
terraform apply -var="username=$TF_VAR_username"

# Test the application
ALB_DNS=$(terraform output -raw load_balancer_dns)
echo "Application URL: http://$ALB_DNS"

# Test multiple times to see load balancing
for i in {1..5}; do
  echo "Request $i:"
  curl -s "http://$ALB_DNS" | grep -o "Server [0-9]"
  sleep 1
done
```

---

## Lab Summary

**What You Accomplished:**
- Designed and implemented a production-ready VPC with a 2-tier architecture
- Deployed infrastructure across multiple Availability Zones for high availability
- Configured networking with a single NAT Gateway and proper routing
- Implemented layered security with ALB and web server security groups
- Deployed an Application Load Balancer with health checks and target groups
- Placed web servers in private subnets for enhanced security

**Key Networking Concepts Mastered:**
- **VPC Design**: 2-tier architecture with proper CIDR planning
- **High Availability**: Multi-AZ deployment patterns
- **Security**: Network segmentation with security groups
- **Routing**: Routing with a NAT Gateway and route tables
- **Load Balancing**: Application Load Balancer configuration and health checks

**Production-Ready Features:**
- Internet Gateway for public subnet connectivity
- Single NAT Gateway for cost-optimized private subnet internet access
- Private subnet isolation for web server security
- Application Load Balancer for high availability and scalability
- Health checks (`/health.html`) and automatic failover capabilities

---

## Cleanup
```bash
terraform destroy -var="username=$TF_VAR_username"
```

---

## Next Steps

In **Lab 10**, you will explore **Terraform Cloud** for remote state management, collaborative workflows, and centralized execution of Terraform runs.
