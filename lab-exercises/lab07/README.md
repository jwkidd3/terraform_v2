# Lab 7: Working with Terraform Registry Modules
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 2
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Use Terraform Registry modules in your configurations
- Combine multiple registry modules to build infrastructure
- Configure module inputs and consume module outputs
- Apply module versioning and best practices
- Build a simple multi-tier application using proven modules

---

## 📋 **Prerequisites**
- Completion of Labs 2-6
- Understanding of module basics from Lab 5
- State management concepts from Lab 6
- Basic VPC networking knowledge

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 7.1: VPC and Security with Registry Modules (25 minutes)**

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab7
cd terraform-lab7
```

### Step 2: Basic VPC Infrastructure
We'll use the popular VPC module from the Terraform Registry to create our networking foundation.

**main.tf:**
```hcl
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
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Owner       = var.username
    Environment = var.environment
    Project     = "RegistryModules"
    ManagedBy   = "Terraform"
    Lab         = "7"
  }
}
```

### Step 3: Add VPC Registry Module
Add the following to your **main.tf** after the locals block:

```hcl
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
```

> **Key Concept:** The `terraform-aws-modules/vpc/aws` module is one of the most popular Terraform Registry modules. It creates a complete VPC with subnets, routing, NAT gateways, and more — saving hundreds of lines of configuration.

### Step 4: Add Security Group Registry Modules
Append to **main.tf**:

```hcl
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
```

> **Key Concept:** The security group module provides pre-built submodules for common protocols (HTTP, SSH, HTTPS, etc.), reducing boilerplate.

### Step 5: Add EC2 Instances and Load Balancer
Append to **main.tf**:

```hcl
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
```

---

## 📦 **Exercise 7.2: S3 Registry Module and Outputs (15 minutes)**

### Step 1: Add S3 Bucket Module
Append to **main.tf**:

```hcl
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
```

### Step 2: Create Outputs File
**outputs.tf:**
```hcl
output "vpc_info" {
  description = "VPC information from registry module"
  value = {
    vpc_id             = module.vpc.vpc_id
    vpc_cidr_block     = module.vpc.vpc_cidr_block
    private_subnet_ids = module.vpc.private_subnets
    public_subnet_ids  = module.vpc.public_subnets
    nat_gateway_ids    = module.vpc.natgw_ids
    internet_gateway_id = module.vpc.igw_id
  }
}

output "security_groups" {
  description = "Security group information from registry modules"
  value = {
    web_security_group_id = module.web_security_group.security_group_id
    ssh_security_group_id = module.ssh_security_group.security_group_id
  }
}

output "application_endpoint" {
  description = "Application load balancer DNS name"
  value = "http://${aws_lb.main.dns_name}"
}

output "web_servers" {
  description = "Web server instances"
  value = {
    for i, instance in aws_instance.web : "web-${i + 1}" => {
      id         = instance.id
      private_ip = instance.private_ip
      subnet_id  = instance.subnet_id
    }
  }
}

output "s3_bucket" {
  description = "S3 bucket information from registry module"
  value = {
    bucket_id                   = module.s3_logs.s3_bucket_id
    bucket_arn                  = module.s3_logs.s3_bucket_arn
    bucket_domain_name          = module.s3_logs.s3_bucket_bucket_domain_name
    bucket_regional_domain_name = module.s3_logs.s3_bucket_bucket_regional_domain_name
  }
}
```

### Step 3: Create Variable Values File
**terraform.tfvars:**
```hcl
username    = "user1"  # Replace with your username
environment = "development"
```

### Step 4: Deploy the Infrastructure
```bash
# Initialize - this downloads all registry modules
terraform init

# Review the plan - notice how many resources the modules create
terraform plan

# Apply the configuration
terraform apply
```

### Step 5: Explore the Outputs
```bash
# View all outputs
terraform output

# View specific outputs
terraform output vpc_info
terraform output application_endpoint
terraform output web_servers
```

### Step 6: Inspect Module Resources
```bash
# List all resources including module resources
terraform state list

# Notice how module resources are prefixed with module.<name>
# For example: module.vpc.aws_vpc.this[0]
```

> **Key Concept:** Registry modules abstract away complexity. The VPC module alone creates 20+ resources (VPC, subnets, route tables, NAT gateways, etc.) from just a few lines of configuration.

---

## 🧹 **Cleanup**
```bash
terraform destroy
```

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **Registry Modules** - Used community-maintained VPC, security group, and S3 modules
✅ **Module Composition** - Combined multiple modules into a cohesive infrastructure
✅ **Module Versioning** - Pinned module versions with `~>` constraints
✅ **Module Outputs** - Consumed outputs from registry modules to connect resources
✅ **Load Balancing** - Built an ALB distributing traffic across EC2 instances

### Key Concepts Learned
- **Terraform Registry**: Central repository of community and verified modules
- **Module Sources**: Using `terraform-aws-modules/<name>/aws` format
- **Version Constraints**: Pinning with `~> 5.0` allows patch updates only
- **Module Composition**: Connecting modules via their outputs (e.g., `module.vpc.vpc_id`)
- **Submodules**: Using `//modules/<name>` syntax for module subcomponents

### Best Practices
- Always pin module versions to avoid unexpected changes
- Use verified modules (checkmark badge) from the Terraform Registry
- Read module documentation for required and optional inputs
- Use `terraform state list` to understand what modules create
- Prefer registry modules over writing custom code for common patterns

---

## 🎓 **Next Steps**
In **Lab 8**, we'll explore **multi-environment patterns** and **workspace management** to handle different deployment stages effectively.

**Key topics coming up:**
- Environment-specific configurations with tfvars
- Feature flags for environment capabilities
- Cost optimization strategies
- Multi-environment deployment patterns
