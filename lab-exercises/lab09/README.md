# Lab 9: VPC Networking and Multi-Tier Architecture
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Design and implement a production-ready VPC with public and private subnets
- Configure advanced routing, NAT Gateways, and Internet connectivity
- Deploy a multi-tier application architecture across availability zones
- Implement proper security group rules for network segmentation
- Configure Application Load Balancer with health checks and target groups

---

## 📋 **Prerequisites**
- Completion of Labs 1-7
- Understanding of networking concepts (CIDR, subnets, routing)
- Knowledge of AWS availability zones and regions

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🌐 **Exercise 9.1: Design Multi-Tier VPC Architecture (20 minutes)**

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab9
cd terraform-lab9
```

### Step 2: Create Production-Ready VPC Infrastructure
Let's build a comprehensive VPC that supports a multi-tier application.

**main.tf:**
```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Using local backend for this lab
}

provider "aws" {
  region = "us-east-2"
}

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
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24"]
  
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "VPC-Lab-8"
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

# Database Subnets (for RDS, ElastiCache)
resource "aws_subnet" "database" {
  count = length(local.database_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnets[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-${count.index + 1}"
    Type = "DatabaseSubnet"
    Tier = "Database"
    AZ   = local.availability_zones[count.index]
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(local.public_subnets)

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
    Type = "NATGatewayEIP"
  })
}

# NAT Gateways for private subnet internet access
resource "aws_nat_gateway" "main" {
  count = length(local.public_subnets)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
    AZ   = local.availability_zones[count.index]
  })

  depends_on = [aws_internet_gateway.main]
}

# Route table for public subnets
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

# Route table associations for public subnets
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route tables for private subnets (one per AZ for high availability)
resource "aws_route_table" "private" {
  count = length(local.private_subnets)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
    Type = "PrivateRouteTable"
    AZ   = local.availability_zones[count.index]
  })
}

# Route table associations for private subnets
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Route table for database subnets (no internet access)
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-rt"
    Type = "DatabaseRouteTable"
  })
}

# Route table associations for database subnets
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# Database subnet group for RDS
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}
```

---

## 🛡️ **Exercise 9.2: Implement Security Groups (15 minutes)**

### Step 1: Create Comprehensive Security Groups
Add security group configurations to **main.tf**:

```hcl
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


# Security Group for Database
resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-db-"
  description = "Security group for database servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL/MariaDB from web servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "PostgreSQL from web servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-sg"
    Type = "DatabaseSecurityGroup"
  })
}
```

---

## 🚀 **Exercise 9.3: Deploy Multi-Tier Application (10 minutes)**

### Step 1: Add Application Infrastructure
Continue adding to **main.tf**:

```hcl
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
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

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

### Step 2: Create Web Server User Data Script
Create **user_data_web.sh**:

```bash
#!/bin/bash
yum update -y
yum install -y httpd php mysql

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create dynamic web page
cat <<EOF > /var/www/html/index.php
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Tier Application - Server ${server_id}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f4f4f4; }
        .container { background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 20px; }
        .info-section { background-color: #ecf0f1; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .server-id { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Multi-Tier VPC Application</h1>
            <h2>Server <span class="server-id">${server_id}</span> - Owner: ${username}</h2>
        </div>
        
        <div class="info-section">
            <h3>Infrastructure Details</h3>
            <p><strong>Environment:</strong> ${environment}</p>
            <p><strong>Instance ID:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
            <p><strong>Availability Zone:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone'); ?></p>
            <p><strong>Private IP:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4'); ?></p>
            <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?></p>
        </div>
        
        <div class="info-section">
            <h3>VPC Architecture Features</h3>
            <ul>
                <li>✅ Multi-AZ deployment for high availability</li>
                <li>✅ Private subnets for application tier security</li>
                <li>✅ NAT Gateways for secure outbound internet access</li>
                <li>✅ Application Load Balancer with health checks</li>
                <li>✅ Layered security groups for network segmentation</li>
                <li>✅ Dedicated database subnets (no internet access)</li>
                <li>✅ Private subnets for enhanced security</li>
            </ul>
        </div>
        
        <div class="info-section">
            <h3>Network Configuration</h3>
            <p><strong>VPC CIDR:</strong> 10.0.0.0/16</p>
            <p><strong>Subnet Type:</strong> Private Application Subnet</p>
            <p><strong>Route Table:</strong> Routes through NAT Gateway</p>
            <p><strong>Security Group:</strong> Allows HTTP from ALB only</p>
        </div>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown apache:apache /var/www/html/index.php
chmod 644 /var/www/html/index.php

# Restart Apache to ensure everything is loaded
systemctl restart httpd

# Create health check endpoint
echo "OK" > /var/www/html/health.html
```

### Step 3: Create Outputs
Create **outputs.tf**:

```hcl
output "vpc_info" {
  description = "VPC configuration details"
  value = {
    vpc_id                = aws_vpc.main.id
    vpc_cidr              = aws_vpc.main.cidr_block
    availability_zones    = local.availability_zones
    public_subnet_ids     = aws_subnet.public[*].id
    private_subnet_ids    = aws_subnet.private[*].id
    database_subnet_ids   = aws_subnet.database[*].id
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
    alb_security_group      = aws_security_group.alb.id
    web_security_group      = aws_security_group.web.id
    database_security_group = aws_security_group.database.id
  }
}

output "nat_gateway_ips" {
  description = "Public IP addresses of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}
```

### Step 4: Deploy and Test the Infrastructure
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

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ Designed and implemented a production-ready VPC with multi-tier architecture
- ✅ Deployed infrastructure across multiple Availability Zones for high availability
- ✅ Configured advanced networking with NAT Gateways and proper routing
- ✅ Implemented layered security with purpose-built security groups
- ✅ Deployed Application Load Balancer with health checks and target groups
- ✅ Implemented private subnet architecture for enhanced security
- ✅ Separated tiers with public, private, and database subnets

**Key Networking Concepts Mastered:**
- **VPC Design**: Multi-tier architecture with proper CIDR planning
- **High Availability**: Multi-AZ deployment patterns
- **Security**: Network segmentation with security groups
- **Routing**: Advanced routing with NAT Gateways and route tables
- **Load Balancing**: Application Load Balancer configuration and health checks

**Production-Ready Features:**
- Internet Gateway for public subnet connectivity
- NAT Gateways for secure private subnet internet access
- Database subnet isolation (no internet access)
- Private subnet isolation for web server security
- Application Load Balancer for high availability and scalability
- Health checks and automatic failover capabilities

---

## 🧹 **Cleanup**
```bash
terraform destroy -var="username=$TF_VAR_username"
```

This lab demonstrates enterprise networking patterns that form the foundation of production AWS workloads. The architecture supports scalability, security, and high availability while maintaining operational simplicity.