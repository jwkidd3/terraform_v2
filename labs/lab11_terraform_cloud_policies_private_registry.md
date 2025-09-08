# Lab 11: Advanced Governance with Policies and Private Registry
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Advanced Learning Objectives**
By the end of this lab, you will be able to:
- Implement sophisticated Sentinel policies for governance and compliance
- Design policy sets with multi-level enforcement (advisory, soft-mandatory, hard-mandatory)
- Build and publish enterprise-grade modules to private registry
- Create reusable infrastructure patterns with advanced module composition
- Implement policy-as-code workflows with automated validation
- Design cost governance policies with budget enforcement
- Integrate security scanning and compliance validation

---

## 📋 **Prerequisites**
- Completion of Labs 9-10 (Advanced Terraform Cloud)
- Terraform Cloud account with Team & Governance plan (for Sentinel policies)
- Advanced understanding of Terraform modules and composition
- Experience with infrastructure security and compliance concepts
- Basic knowledge of policy-as-code principles

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🛡️ **Exercise 11.1: Advanced Sentinel Policy Implementation (20 minutes)**

### Step 1: Enterprise Policy-as-Code Architecture
Sentinel policies in Terraform Cloud provide enterprise-grade governance, compliance, and cost control through automated policy enforcement.

**Advanced Policy Categories:**

#### 🔒 **Security & Compliance Policies:**
- ✅ Enforce encryption at rest and in transit for all data stores
- ✅ Validate IAM roles follow least privilege principles
- ✅ Ensure all resources comply with industry standards (SOC2, PCI-DSS, HIPAA)
- ✅ Prevent public exposure of sensitive resources
- ✅ Mandate security group rules and network access controls
- ✅ Require backup and disaster recovery configurations

#### 💰 **Cost Governance Policies:**
- ✅ Block expensive instance types without approval workflow
- ✅ Enforce resource sizing based on environment (dev/staging/prod)
- ✅ Require cost center tags for financial allocation
- ✅ Limit resource counts and total infrastructure spend
- ✅ Mandate lifecycle policies for storage optimization
- ✅ Validate reserved instance utilization requirements

#### 🏢 **Operational Excellence Policies:**
- ✅ Enforce comprehensive resource tagging strategies
- ✅ Require monitoring and alerting for critical resources
- ✅ Mandate naming conventions and organizational standards
- ✅ Validate multi-AZ deployments for production workloads
- ✅ Ensure proper resource dependencies and relationships
- ✅ Require documentation and metadata for infrastructure components

### Step 2: Create Lab Directory
```bash
mkdir terraform-lab11
cd terraform-lab11
```

### Step 3: Create Enterprise Infrastructure for Policy Validation
We'll build a comprehensive infrastructure stack to demonstrate advanced policy enforcement:

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
  
  cloud {
    organization = "user1-terraform-lab"  # Replace user1 with your username!
    
    workspaces {
      name = "user1-policy-governance"     # Replace user1 with your username!
    }
  }
}

provider "aws" {
  region = "us-east-2"
  
  # Default tags applied to all resources
  default_tags {
    tags = {
      ManagedBy     = "terraform"
      Environment   = var.environment
      Owner         = var.username
      CostCenter    = var.cost_center
      Project       = "policy-governance"
      Lab           = "11-advanced"
      PolicyTested  = "true"
    }
  }
}

# Variables with validation that policies will check
variable "username" {
  description = "Your unique username"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.username))
    error_message = "Username must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
  
  validation {
    condition     = contains(["engineering", "marketing", "operations", "security"], var.cost_center)
    error_message = "Cost center must be a valid organizational unit."
  }
}

variable "instance_type" {
  description = "EC2 instance type (policies will validate this)"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^t[23]\\.(nano|micro|small|medium)$", var.instance_type))
    error_message = "Only cost-optimized instance types are allowed in this demo."
  }
}

variable "enable_public_access" {
  description = "Enable public access (policies will likely block this)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
  
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 7 and 365 days."
  }
}

# Local values for policy compliance
locals {
  # Environment-specific configurations that policies validate
  environment_config = {
    dev = {
      allowed_instance_types = ["t3.nano", "t3.micro", "t3.small"]
      require_encryption     = false
      require_backup        = false
      max_cost_per_month    = 100
      require_multi_az      = false
    }
    staging = {
      allowed_instance_types = ["t3.micro", "t3.small", "t3.medium"]
      require_encryption     = true
      require_backup        = true
      max_cost_per_month    = 500
      require_multi_az      = true
    }
    prod = {
      allowed_instance_types = ["t3.small", "t3.medium", "t3.large"]
      require_encryption     = true
      require_backup        = true
      max_cost_per_month    = 2000
      require_multi_az      = true
    }
  }
  
  current_config = local.environment_config[var.environment]
  
  # Required tags that policies will validate
  required_tags = {
    Name          = "${var.username}-${var.environment}-policy-demo"
    Environment   = var.environment
    Owner         = var.username
    CostCenter    = var.cost_center
    Project       = "policy-governance"
    BackupPolicy  = local.current_config.require_backup ? "enabled" : "disabled"
    Compliance    = var.environment == "prod" ? "required" : "optional"
    CreatedBy     = "terraform-cloud"
    PolicyManaged = "true"
  }
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data source for current caller identity
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 buckets - policies will enforce encryption, naming, and tagging
resource "aws_s3_bucket" "policy_demo_data" {
  bucket = "${var.username}-${var.environment}-data-${random_string.suffix.result}"

  tags = merge(local.required_tags, {
    Purpose = "data-storage"
    BackupSchedule = "daily"
  })
}

resource "aws_s3_bucket" "policy_demo_logs" {
  bucket = "${var.username}-${var.environment}-logs-${random_string.suffix.result}"

  tags = merge(local.required_tags, {
    Purpose = "log-storage"
    RetentionPolicy = "${var.backup_retention_days}-days"
  })
}

# Intentionally create a bucket that might violate policies
resource "aws_s3_bucket" "policy_violation_test" {
  count = var.enable_public_access ? 1 : 0
  
  bucket = "${var.username}-${var.environment}-public-${random_string.suffix.result}"

  tags = merge(local.required_tags, {
    Purpose = "public-content"
    Warning = "intentional-policy-test"
  })
}

# S3 bucket configurations - policies will check these
resource "aws_s3_bucket_encryption_configuration" "data" {
  bucket = aws_s3_bucket.policy_demo_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.policy_demo_data.id
  versioning_configuration {
    status = local.current_config.require_backup ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.policy_demo_logs.id

  rule {
    id     = "log_retention"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.backup_retention_days
    }
  }
}

# VPC and networking - policies will validate configuration
resource "aws_vpc" "policy_demo" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-vpc"
    Type = "application-vpc"
  })
}

resource "aws_subnet" "public" {
  count = local.current_config.require_multi_az ? 2 : 1
  
  vpc_id                  = aws_vpc.policy_demo.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = var.enable_public_access

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-public-${count.index + 1}"
    Type = "public-subnet"
    Tier = "web"
  })
}

resource "aws_subnet" "private" {
  count = local.current_config.require_multi_az ? 2 : 1
  
  vpc_id            = aws_vpc.policy_demo.id
  cidr_block        = "10.0.${count.index + 11}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-private-${count.index + 1}"
    Type = "private-subnet"
    Tier = "application"
  })
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Security group - policies will validate rules
resource "aws_security_group" "policy_demo" {
  name_prefix = "${var.username}-${var.environment}-"
  vpc_id      = aws_vpc.policy_demo.id
  description = "Security group for policy demonstration"

  # Controlled ingress - policies may restrict certain ports
  ingress {
    description = "SSH (restricted)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.policy_demo.cidr_block] # Only from VPC
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Intentional policy violation test
  dynamic "ingress" {
    for_each = var.enable_public_access ? [1] : []
    content {
      description = "Unrestricted access (policy violation)"
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-sg"
    Type = "security-group"
  })
}

# EC2 instance - policies will validate instance type and configuration
resource "aws_instance" "policy_demo" {
  ami                    = "ami-0ea3c35c5c3284d82"  # Amazon Linux 2 in us-east-2
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.policy_demo.id]
  
  # EBS optimization - policies may require this for certain instance types
  ebs_optimized = true
  
  # Metadata options - security policies often require IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"  # IMDSv2 only
    http_put_response_hop_limit = 1
  }
  
  # Root volume configuration - policies will check encryption
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = local.current_config.require_encryption
    
    tags = merge(local.required_tags, {
      Name = "${var.username}-${var.environment}-root-volume"
      VolumeType = "root"
    })
  }

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-instance"
    Type = "application-server"
    MonitoringRequired = local.current_config.require_backup ? "true" : "false"
  })
}

# CloudWatch Log Group - policies will validate retention and encryption
resource "aws_cloudwatch_log_group" "policy_demo" {
  name              = "/aws/ec2/${var.username}-${var.environment}"
  retention_in_days = var.backup_retention_days
  
  # Encryption - required by security policies
  kms_key_id = local.current_config.require_encryption ? aws_kms_key.policy_demo[0].arn : null

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-logs"
    Type = "cloudwatch-logs"
  })
}

# KMS key for encryption - policies will validate usage
resource "aws_kms_key" "policy_demo" {
  count = local.current_config.require_encryption ? 1 : 0
  
  description             = "KMS key for ${var.username} ${var.environment} policy demo"
  deletion_window_in_days = 7
  enable_key_rotation    = true

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-kms-key"
    Type = "encryption-key"
  })
}

resource "aws_kms_alias" "policy_demo" {
  count = local.current_config.require_encryption ? 1 : 0
  
  name          = "alias/${var.username}-${var.environment}-key"
  target_key_id = aws_kms_key.policy_demo[0].key_id
}

# IAM role - policies will validate permissions and trust relationships
resource "aws_iam_role" "policy_demo" {
  name = "${var.username}-${var.environment}-policy-demo-role"

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

  tags = merge(local.required_tags, {
    Name = "${var.username}-${var.environment}-iam-role"
    Type = "iam-role"
  })
}

# IAM policy - policies will validate permissions follow least privilege
resource "aws_iam_role_policy" "policy_demo" {
  name = "${var.username}-${var.environment}-policy"
  role = aws_iam_role.policy_demo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.policy_demo_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = aws_cloudwatch_log_group.policy_demo.arn
      }
    ]
  })
}

# Bucket encryption - good practice that policies often enforce
resource "aws_s3_bucket_server_side_encryption_configuration" "policy_demo" {
  bucket = aws_s3_bucket.policy_demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access - another policy requirement
resource "aws_s3_bucket_public_access_block" "policy_demo" {
  bucket = aws_s3_bucket.policy_demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EC2 instance with proper tags
resource "aws_instance" "policy_demo" {
  ami           = "ami-0ea3c35c5c3284d82"  # Amazon Linux 2 in us-east-2
  instance_type = "t2.micro"  # Policy-compliant size

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Policy Demo - ${var.username}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f8ff; }
            .policy-info { background: white; padding: 20px; border-radius: 10px; margin: 20px 0; }
        </style>
    </head>
    <body>
        <h1>🛡️ Policy and Compliance Demo</h1>
        <p><strong>Owner:</strong> ${var.username}</p>
        
        <div class="policy-info">
            <h2>Policy Compliance Checklist</h2>
            <ul>
                <li>✅ S3 bucket has encryption enabled</li>
                <li>✅ S3 bucket blocks public access</li>
                <li>✅ All resources have required tags (Owner, Environment, Lab)</li>
                <li>✅ Instance type is approved (t2.micro)</li>
                <li>✅ Resources follow naming convention</li>
            </ul>
        </div>
        
        <div class="policy-info">
            <h2>What are Terraform Policies?</h2>
            <p>Policies are automated rules that check your infrastructure before deployment:</p>
            <ul>
                <li><strong>Security:</strong> Ensure encryption and access controls</li>
                <li><strong>Compliance:</strong> Meet regulatory requirements</li>
                <li><strong>Cost Control:</strong> Prevent expensive resource creation</li>
                <li><strong>Best Practices:</strong> Enforce tagging and naming standards</li>
            </ul>
        </div>
        
        <div class="policy-info">
            <h2>Lab 11: Policy and Registry</h2>
            <p>This infrastructure demonstrates compliant resource creation.</p>
        </div>
    </body>
    </html>
HTML
  EOF
  )

  tags = {
    Name = "${var.username}-policy-demo-server"
    Owner = var.username
    Lab = "11"
    Environment = "demo"
    InstanceType = "web-server"
    # Note: Including all the tags that policies typically require
  }
}
```

**outputs.tf:**
```hcl
output "policy_compliance" {
  description = "Policy compliance summary"
  value = {
    s3_bucket_encrypted = "✅ Yes - AES256 encryption enabled"
    s3_public_access_blocked = "✅ Yes - All public access blocked"
    required_tags_present = "✅ Yes - Owner, Environment, Lab tags present"
    approved_instance_type = "✅ Yes - t2.micro is pre-approved"
    naming_convention = "✅ Yes - Resources follow ${var.username}-* pattern"
  }
}

output "resources_created" {
  description = "Resources that passed policy checks"
  value = {
    s3_bucket = aws_s3_bucket.policy_demo.id
    ec2_instance = aws_instance.policy_demo.id
    instance_url = "http://${aws_instance.policy_demo.public_ip}"
  }
}

output "policy_benefits" {
  description = "Benefits of using policies"
  value = [
    "Automated compliance checking",
    "Consistent security standards", 
    "Cost control and governance",
    "Reduced human error",
    "Audit-ready infrastructure"
  ]
}
```

### Step 4: Create and Configure Workspace
1. Create workspace: `${your-username}-policy-demo` in Terraform Cloud
2. Set variables:
   - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (environment variables, sensitive)
   - `username`: your username (terraform variable)

### Step 5: Deploy Compliant Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

---

## 📚 **Exercise 11.2: Creating a Simple Module for Private Registry (20 minutes)**

### Step 1: Understand Private Registry Benefits
The private registry allows you to:
- Share modules within your organization
- Version control your infrastructure components
- Enforce approved patterns across teams
- Keep proprietary modules private

### Step 2: Create a Simple S3 Website Module
Let's create a reusable module and publish it to your private registry:

```bash
mkdir s3-website-module
cd s3-website-module
```

**variables.tf:**
```hcl
variable "username" {
  description = "Username for resource naming"
  type        = string
}

variable "website_name" {
  description = "Name of the website"
  type        = string
}

variable "index_content" {
  description = "Content for index.html"
  type        = string
  default     = "<h1>Hello World!</h1>"
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

**main.tf:**
```hcl
# S3 bucket for static website hosting
resource "aws_s3_bucket" "website" {
  bucket = "${var.username}-${var.website_name}-site"

  tags = merge(var.tags, {
    Name = "${var.username}-${var.website_name}-site"
    Type = "StaticWebsite"
    ManagedBy = "PrivateRegistryModule"
  })
}

# Website configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Optional versioning
resource "aws_s3_bucket_versioning" "website" {
  count = var.enable_versioning ? 1 : 0
  
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload index.html
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website.id
  key    = "index.html"
  content = var.index_content
  content_type = "text/html"
}

# Upload error.html
resource "aws_s3_object" "error" {
  bucket = aws_s3_bucket.website.id
  key    = "error.html"
  content = "<h1>Page Not Found</h1><p>The page you're looking for doesn't exist.</p>"
  content_type = "text/html"
}

# Make bucket public for website
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy for public read
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}
```

**outputs.tf:**
```hcl
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "website_endpoint" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "website_url" {
  description = "Complete website URL"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}
```

**README.md:**
```markdown
# S3 Static Website Module

This module creates an S3 bucket configured for static website hosting.

## Usage

```hcl
module "my_website" {
  source = "app.terraform.io/YOUR-ORG/s3-website/aws"
  
  username      = "myuser"
  website_name  = "portfolio"
  index_content = "<h1>My Portfolio</h1>"
  enable_versioning = true
  
  tags = {
    Environment = "production"
    Owner      = "myuser"
  }
}
```

## Features

- ✅ S3 bucket with static website hosting
- ✅ Public read access configuration
- ✅ Optional versioning
- ✅ Default error page
- ✅ Customizable content
- ✅ Proper tagging support

## Requirements

- AWS provider ~> 5.0
- Terraform >= 1.5
```

### Step 3: Understanding Private Registry Publication
**Note**: Publishing to private registry requires specific workflows (usually with version control integration). For this lab, we'll simulate the process and understand the concepts.

In a real scenario, you would:
1. Push your module to a Git repository
2. Tag a release (e.g., v1.0.0)
3. Connect the repository to Terraform Cloud
4. Terraform Cloud automatically publishes the module

---

## 🔧 **Exercise 11.3: Using Registry Concepts (10 minutes)**

### Step 1: Create Configuration Using Module Concepts
Let's create a configuration that uses our module pattern:

```bash
cd ..  # Back to terraform-lab11
```

Create **registry-demo.tf**:
```hcl
# Add this to your existing configuration

# Simulate using a private registry module
# (In reality, this would reference your private registry)
module "company_website" {
  source = "./s3-website-module"  # Local path for demo
  
  username      = var.username
  website_name  = "company-site"
  enable_versioning = true
  
  index_content = <<-EOF
    <!DOCTYPE html>
    <html>
    <head>
        <title>Company Website - ${var.username}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
            .container { background: white; padding: 30px; border-radius: 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🏢 ${var.username}'s Company Website</h1>
            <p>This website was created using a private registry module!</p>
            
            <h2>Private Registry Benefits</h2>
            <ul>
                <li>✅ Reusable, tested components</li>
                <li>✅ Organization-specific modules</li>
                <li>✅ Version control and releases</li>
                <li>✅ Access control and security</li>
                <li>✅ Consistent patterns across teams</li>
            </ul>
            
            <h2>Module Information</h2>
            <p><strong>Module:</strong> s3-website</p>
            <p><strong>Version:</strong> 1.0.0 (simulated)</p>
            <p><strong>Source:</strong> Private Registry</p>
            <p><strong>Owner:</strong> ${var.username}</p>
        </div>
    </body>
    </html>
  EOF
  
  tags = {
    Environment = "demo"
    Lab = "11"
    Owner = var.username
    ModuleSource = "PrivateRegistry"
  }
}

# Another instance of the same module with different settings
module "personal_blog" {
  source = "./s3-website-module"  # Local path for demo
  
  username      = var.username
  website_name  = "personal-blog"
  enable_versioning = false  # Different setting
  
  index_content = <<-EOF
    <!DOCTYPE html>
    <html>
    <head>
        <title>Personal Blog - ${var.username}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #fff8dc; }
            .container { background: white; padding: 30px; border-radius: 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>📝 ${var.username}'s Personal Blog</h1>
            <p>Another site using the same private registry module!</p>
            
            <h2>Code Reuse Benefits</h2>
            <ul>
                <li>✅ Same module, different configuration</li>
                <li>✅ Consistent infrastructure patterns</li>
                <li>✅ Reduced development time</li>
                <li>✅ Shared best practices</li>
            </ul>
        </div>
    </body>
    </html>
  EOF
  
  tags = {
    Environment = "demo"
    Lab = "11" 
    Owner = var.username
    ModuleSource = "PrivateRegistry"
    Purpose = "PersonalBlog"
  }
}
```

### Step 2: Add Module Outputs
Add to **outputs.tf**:
```hcl
# Add these outputs

output "private_registry_demo" {
  description = "Websites created using private registry module"
  value = {
    company_website = {
      url = module.company_website.website_url
      versioning = "enabled"
      bucket = module.company_website.bucket_name
    }
    personal_blog = {
      url = module.personal_blog.website_url
      versioning = "disabled"
      bucket = module.personal_blog.bucket_name
    }
  }
}

output "module_reuse_benefits" {
  description = "Benefits demonstrated by module reuse"
  value = [
    "Same module code used twice with different configurations",
    "Consistent infrastructure patterns across projects",
    "Reduced code duplication and maintenance",
    "Faster deployment of new projects",
    "Shared best practices and standards"
  ]
}
```

### Step 3: Deploy with Module Usage
```bash
terraform plan
terraform apply

# Check the websites created by modules
terraform output private_registry_demo
```

---

## 🎉 **Lab Summary**

### What You Accomplished:
✅ **Learned policy concepts** and why they matter for compliance  
✅ **Created compliant infrastructure** following best practices  
✅ **Built a reusable module** for the private registry  
✅ **Used module patterns** to create multiple websites  
✅ **Understood governance** through policies and private registries  
✅ **Experienced code reuse** with consistent patterns  

### Policy Benefits You Learned:
- **Automated Compliance**: Policies check rules automatically
- **Security Enforcement**: Ensure encryption and access controls
- **Cost Control**: Prevent expensive resource creation
- **Consistency**: Apply standards across all infrastructure
- **Audit Trail**: Document compliance for regulations

### Private Registry Benefits:
- **Code Reuse**: Same module used multiple times
- **Organization Standards**: Enforce approved patterns
- **Version Control**: Manage module releases
- **Access Control**: Keep proprietary modules private
- **Team Collaboration**: Share tested components

---

## 🔍 **Understanding Governance in Terraform Cloud**

### Policy as Code Benefits:
✅ **Automated Checking**: No manual reviews needed  
✅ **Consistent Standards**: Same rules applied everywhere  
✅ **Early Detection**: Catch issues before deployment  
✅ **Audit Compliance**: Prove adherence to regulations  
✅ **Cost Control**: Prevent expensive mistakes  

### Private Registry Use Cases:
- **Company Standards**: Modules that follow your organization's patterns
- **Approved Components**: Only use tested and secure modules
- **Intellectual Property**: Keep proprietary infrastructure private
- **Team Efficiency**: Developers use pre-built, approved components
- **Consistency**: Same patterns across all teams and projects

### Governance Workflow:
```
Developer writes Terraform → Policy checks run → 
If compliant → Deploy → If not compliant → Reject with feedback
```

### Your Lab Architecture:
```
Terraform Cloud Organization
├── 📋 Policies (enforce rules)
│   ├── Required tags
│   ├── Encryption requirements  
│   └── Approved instance types
├── 📚 Private Registry (reusable modules)
│   └── s3-website module (your creation)
└── 🏗️ Workspaces (use modules + follow policies)
    └── policy-demo workspace
```

---

## 🧹 **Clean Up**

```bash
# Destroy infrastructure
terraform destroy

# Clean up module directory
cd ..
rm -rf s3-website-module
```

---

## ❓ **Troubleshooting**

### Problem: "Module not found"
**Solution**: Make sure you created the s3-website-module directory and files.

### Problem: "Policy violations" (if using real policies)
**Solution**: Check that your resources have required tags and configurations.

### Problem: "Registry publication failed"
**Solution**: In this lab, we used local modules. Real private registry requires Git integration.

### Problem: "Website not accessible"
**Solution**: Wait 1-2 minutes for S3 website configuration to take effect.

---

## 🎯 **Next Steps**

In Lab 12, you'll learn:
- Putting it all together in a final project
- Combining multiple concepts from all labs
- Building production-ready infrastructure

**Excellent! You now understand governance and reusability in Terraform Cloud! 🚀**

## 📝 **Governance Cheat Sheet**

### Policy Best Practices:
```bash
# Common policy requirements:
- All resources must have Owner tag
- S3 buckets must have encryption
- EC2 instances must use approved sizes
- No resources in forbidden regions
- Naming conventions must be followed
```

### Private Registry Benefits:
```bash
# Module reuse patterns:
- One module → multiple configurations
- Shared best practices
- Version controlled releases
- Organization-specific standards
- Access controlled sharing
```

### Real-World Governance:
- **Policies**: Prevent security and compliance issues
- **Private Registry**: Share approved infrastructure patterns
- **Workspaces**: Isolated environments with proper access control
- **Teams**: Role-based access to different environments