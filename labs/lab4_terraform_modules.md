# Lab 4: Creating and Using Terraform Modules
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 1  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Create reusable Terraform modules with multiple resources
- Design modules with proper variable validation and outputs
- Use modules to deploy infrastructure with consistent patterns
- Understand module composition and dependency management

---

## 📋 **Prerequisites**
- Completion of Labs 1-3
- Understanding of basic variables and resources

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 📦 **Exercise 4.1: Create a Web Application Module (25 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab4
cd terraform-lab4

# Create module directory
mkdir -p modules/web-application
```

### Step 2: Create a Comprehensive Web Application Module
Create the module files:

**modules/web-application/variables.tf:**
```hcl
# Module input variables with validation
variable "username" {
  description = "Your unique username"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters, lowercase letters and numbers only."
  }
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,30}$", var.app_name))
    error_message = "App name must be 3-30 characters, letters, numbers, and hyphens only."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for EC2 instance"
  type        = bool
  default     = true
}
```

**modules/web-application/main.tf:**
```hcl
# Local values for consistent resource naming
locals {
  name_prefix = "${var.username}-${var.app_name}-${var.environment}"
  
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}

# Data sources to make our module flexible
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# S3 bucket for application assets
resource "aws_s3_bucket" "app_assets" {
  bucket = "${local.name_prefix}-assets-${random_string.bucket_suffix.result}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-assets"
    Type = "ApplicationAssets"
  })
}

# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Security group for web server
resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-web-"
  description = "Security group for ${var.app_name} web server"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
  })
}

# IAM role for EC2 to access S3
resource "aws_iam_role" "web_server" {
  name = "${local.name_prefix}-web-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for S3 access
resource "aws_iam_role_policy" "web_server_s3" {
  name = "${local.name_prefix}-s3-access"
  role = aws_iam_role.web_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_assets.arn,
          "${aws_s3_bucket.app_assets.arn}/*"
        ]
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "web_server" {
  name = "${local.name_prefix}-web-server-profile"
  role = aws_iam_role.web_server.name

  tags = local.common_tags
}

# EC2 instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  availability_zone      = data.aws_availability_zones.available.names[0]
  iam_instance_profile   = aws_iam_instance_profile.web_server.name
  monitoring             = var.enable_monitoring

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name    = var.app_name
    environment = var.environment
    username    = var.username
    bucket_name = aws_s3_bucket.app_assets.id
  }))

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-server"
  })
}

# CloudWatch alarm for CPU utilization
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = local.common_tags
}
```

**modules/web-application/user_data.sh:**
```bash
#!/bin/bash
yum update -y
yum install -y httpd aws-cli

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create a dynamic web page
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>${app_name} - ${environment}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #232f3e; color: white; padding: 20px; }
        .content { padding: 20px; }
        .info-box { background-color: #f0f0f0; padding: 15px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Welcome to ${app_name}!</h1>
        <h2>Environment: ${environment}</h2>
    </div>
    <div class="content">
        <div class="info-box">
            <h3>Application Details</h3>
            <p><strong>Owner:</strong> ${username}</p>
            <p><strong>Server launched:</strong> $(date)</p>
            <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
            <p><strong>S3 Bucket:</strong> ${bucket_name}</p>
        </div>
        <div class="info-box">
            <h3>Module Features Demonstrated</h3>
            <ul>
                <li>✅ Variable validation and defaults</li>
                <li>✅ Local values and consistent naming</li>
                <li>✅ Data sources for dynamic resource selection</li>
                <li>✅ IAM roles and policies for secure S3 access</li>
                <li>✅ CloudWatch monitoring and alarms</li>
                <li>✅ Template files for dynamic content</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

# Test S3 connectivity and upload a test file
echo "Testing S3 connectivity..." > /tmp/test-file.txt
aws s3 cp /tmp/test-file.txt s3://${bucket_name}/test-connection.txt
```

**modules/web-application/outputs.tf:**
```hcl
# Module outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "website_url" {
  description = "URL to access the website"
  value       = "http://${aws_instance.web.public_ip}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for assets"
  value       = aws_s3_bucket.app_assets.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.web_server.arn
}
```

---

## 🏗️ **Exercise 4.2: Use Your Module Multiple Times (15 minutes)**

### Step 1: Create main configuration
Create your main Terraform files:

**variables.tf:**
```hcl
variable "username" {
  description = "Your unique username"
  type        = string
}
```

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
}

provider "aws" {
  region = "us-east-2"
}

# Use the module to create a development application
module "dev_blog" {
  source = "./modules/web-application"

  username         = var.username
  app_name         = "my-blog"
  environment      = "dev"
  instance_type    = "t3.micro"
  enable_monitoring = true
}

# Use the same module to create a different application
module "staging_portfolio" {
  source = "./modules/web-application"

  username         = var.username
  app_name         = "portfolio"
  environment      = "staging"
  instance_type    = "t3.small"
  enable_monitoring = false
}
```

**outputs.tf:**
```hcl
# Output information from both module instances
output "dev_blog_info" {
  description = "Information about the dev blog application"
  value = {
    website_url     = module.dev_blog.website_url
    instance_id     = module.dev_blog.instance_id
    s3_bucket       = module.dev_blog.s3_bucket_name
  }
}

output "staging_portfolio_info" {
  description = "Information about the staging portfolio application"
  value = {
    website_url     = module.staging_portfolio.website_url
    instance_id     = module.staging_portfolio.instance_id
    s3_bucket       = module.staging_portfolio.s3_bucket_name
  }
}

output "all_websites" {
  description = "Quick access to all website URLs"
  value = {
    "Dev Blog"          = module.dev_blog.website_url
    "Staging Portfolio" = module.staging_portfolio.website_url
  }
}
```

### Step 2: Deploy and Test Your Module
```bash
# Initialize and apply
terraform init
terraform apply

# After applying, test both websites
echo "Dev Blog URL: $(terraform output -raw dev_blog_info | jq -r '.website_url')"
echo "Portfolio URL: $(terraform output -raw staging_portfolio_info | jq -r '.website_url')"
```

---

## 🔍 **Exercise 4.3: Module Analysis and Improvement (5 minutes)**

### Step 1: Analyze What You've Built
Answer these questions about your module:

1. **Reusability**: How does using the same module twice demonstrate reusability?
2. **Flexibility**: What makes this module flexible for different use cases?
3. **Best Practices**: What Terraform best practices does this module implement?
4. **Security**: How does the module implement security best practices?

### Step 2: Test Module Validation
Try these commands to see variable validation in action:

```bash
# This should fail validation - try it!
terraform apply -var="username=USER-123-INVALID"

# This should also fail - try it!
terraform apply -var="username=user1" -replace="module.dev_blog.aws_instance.web" \
  -var="dev_blog_environment=invalid"
```

---

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ Created a comprehensive, reusable Terraform module with 8+ resources
- ✅ Implemented variable validation and smart defaults
- ✅ Used data sources for dynamic resource selection
- ✅ Integrated IAM roles, S3 storage, and CloudWatch monitoring
- ✅ Deployed the same module with different configurations
- ✅ Created outputs for easy access to resource information

**Key Module Design Concepts Learned:**
- **Input Validation**: Using validation blocks to ensure correct input
- **Local Values**: Creating consistent naming and tagging patterns
- **Data Sources**: Making modules flexible across different AWS regions/accounts
- **Template Files**: Dynamic content generation using templatefile()
- **Conditional Resources**: Using count to conditionally create resources
- **Output Design**: Providing useful information for module consumers

**Advanced Features Implemented:**
- IAM roles and policies for secure service integration
- CloudWatch monitoring with conditional creation
- S3 bucket with versioning and encryption
- Dynamic user data with template interpolation
- Resource dependencies and proper ordering

---

## 🧹 **Cleanup**
```bash
terraform destroy
```

Remember: This module demonstrates production-ready patterns while remaining focused on core learning objectives. Each component serves a specific purpose in teaching module design and Terraform best practices.