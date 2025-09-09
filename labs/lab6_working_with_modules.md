# Lab 6: Working with Terraform Registry Modules
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
- Completion of Labs 1-5
- Understanding of module basics from Lab 4
- Remote state setup from Lab 5
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

## 🏗️ **Exercise 6.1: VPC and Security with Registry Modules (25 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab6
cd terraform-lab6
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
  # Remote state configuration is covered in Lab 5
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
    Lab         = "6"
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
```

### Step 3: Create outputs file
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
```

### Step 4: Deploy the Infrastructure
```bash
# Initialize and apply
terraform init
terraform plan
terraform apply
```

### Step 5: Test the Registry Modules
```bash
# View the outputs to see module results
terraform output

# Test the application
echo "Testing application endpoint:"
APPLICATION_URL=$(terraform output -raw application_endpoint)
echo "Application URL: $APPLICATION_URL"
echo "Note: It may take a few minutes for the load balancer to become healthy"
```

---

## 🔍 **Exercise 6.2: Exploring Module Features (10 minutes)**

### Step 1: Examine Module Documentation
Visit the Terraform Registry and explore the modules we used:

1. **VPC Module**: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
2. **Security Group Module**: https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest

### Step 2: Add S3 Module
Let's add an S3 bucket for application logs using another registry module.

Add to **main.tf:**
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
    enabled = true
  }

  # Server-side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
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

Add to **outputs.tf:**
```hcl
output "s3_bucket" {
  description = "S3 bucket information from registry module"
  value = {
    bucket_id                 = module.s3_logs.s3_bucket_id
    bucket_arn               = module.s3_logs.s3_bucket_arn
    bucket_domain_name       = module.s3_logs.s3_bucket_bucket_domain_name
    bucket_regional_domain_name = module.s3_logs.s3_bucket_bucket_regional_domain_name
  }
}
```

### Step 3: Apply the Changes
```bash
terraform plan
terraform apply
```

---

## 🧪 **Exercise 6.3: Module Versioning and Best Practices (10 minutes)**

### Step 1: Understanding Module Versioning
Review the version constraints in our configuration:

```hcl
# Different versioning approaches
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"      # Allow 5.x updates, but not 6.x
}

module "s3_logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"  
  version = "~> 3.0"      # Allow 3.x updates, but not 4.x
}

# More restrictive versioning for production
# version = "5.1.2"       # Pin to exact version
# version = ">= 5.1.0, < 5.2.0"  # Range constraint
```

### Step 2: Module Configuration Best Practices

**Review what we implemented:**

1. **Clear naming**: All resources use consistent prefixes
2. **Proper tagging**: Common tags applied across all resources  
3. **Version pinning**: Using `~>` constraints for stability
4. **Input validation**: Username validation rules
5. **Logical outputs**: Structured outputs for downstream consumption
6. **Environment awareness**: Different settings for different environments

### Step 3: Verify Module Registry Information
```bash
# Check what modules are being used
terraform providers
terraform version

# View the module dependency tree
terraform graph | head -20
```

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **Used Terraform Registry modules** - VPC, Security Groups, and S3 modules  
✅ **Combined multiple modules** - Created a cohesive infrastructure stack  
✅ **Applied module versioning** - Used proper version constraints  
✅ **Configured module inputs** - Customized modules for your environment  
✅ **Consumed module outputs** - Used outputs to connect resources  
✅ **Built multi-tier architecture** - Load balancer, web servers, and storage  

### Key Concepts Learned
- **Module sources**: Registry vs local vs Git
- **Version constraints**: `~>`, `>=`, and exact versions
- **Module composition**: Combining modules effectively
- **Input/output patterns**: Proper module interfaces
- **Best practices**: Naming, tagging, and organization

### Registry Modules Used
- **terraform-aws-modules/vpc/aws** - Complete VPC infrastructure
- **terraform-aws-modules/security-group/aws** - Reusable security groups
- **terraform-aws-modules/s3-bucket/aws** - Configured S3 buckets

---

## 🧹 **Cleanup**
```bash
terraform destroy
```

---

## 🎓 **Next Steps**
In **Lab 7**, we'll explore **multi-environment patterns** and **workspace management** to handle different deployment stages effectively.

**Key topics coming up:**
- Terraform workspaces
- Environment-specific configurations
- Variable precedence patterns
- Deployment strategies