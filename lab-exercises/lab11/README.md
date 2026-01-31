# Lab 11: Terraform Cloud Workspaces
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Create and manage multiple Terraform Cloud workspaces
- Configure workspace variables and settings
- Understand workspace organization and naming patterns
- Use workspace tags for organization
- Configure basic workspace automation

---

## 📋 **Prerequisites**
- Completion of Lab 10 (Terraform Cloud Integration)
- Terraform Cloud account (free tier sufficient)
- Understanding of basic Terraform concepts

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 11.1: Multiple Workspaces (20 minutes)**

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab11
cd terraform-lab11
```

### Step 2: Simple Infrastructure Configuration

> **Note — CLI-driven workflow authentication:** Since this lab uses the **CLI-driven workflow**, you do not need a `cloud {}` block in your configuration. Instead, authenticate with `terraform login` (shown in Exercise 11.4) and select the target workspace with `terraform workspace select`. Terraform Cloud will manage remote state and execution automatically once the workspace is selected.

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
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 1
}

variable "username" {
  description = "Your unique username"
  type        = string
}

# Simple S3 bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket        = "${var.environment}-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform-Cloud"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Simple EC2 instances
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name        = "${var.environment}-instance-${count.index + 1}"
    Environment = var.environment
  }
}
```

**outputs.tf:**
```hcl
output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app_bucket.id
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.app[*].id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
```

### Step 3: Create Configuration Files
```bash
# Create the files with the content above
# Then push to GitHub or upload manually
git init
git add .
git commit -m "Initial workspace configuration"
```

---

## ☁️ **Exercise 11.2: Create Development Workspace (10 minutes)**

### Step 1: Create Development Workspace
1. Go to Terraform Cloud: https://app.terraform.io
2. In your organization, click **New Workspace**
3. Choose **CLI-driven workflow** (easier for learning)
4. Workspace name: `lab11-development`
5. Description: "Development environment workspace"

### Step 2: Configure Workspace Variables
Add these **Environment Variables**:
- `AWS_ACCESS_KEY_ID` (sensitive)
- `AWS_SECRET_ACCESS_KEY` (sensitive)
- `AWS_DEFAULT_REGION` = `us-east-2`

Add these **Terraform Variables**:
- `environment` = `development`
- `instance_count` = `1`

### Step 3: Configure Workspace Settings
1. Go to **Settings** → **General**
2. Add **Tags**: `environment:development`, `team:training`
3. **Execution Mode**: Remote (default)
4. **Apply Method**: Manual apply (safer for learning)

---

## 🚀 **Exercise 11.3: Create Staging Workspace (10 minutes)**

### Step 1: Create Staging Workspace
1. Click **New Workspace**
2. **CLI-driven workflow**
3. Workspace name: `lab11-staging`
4. Description: "Staging environment workspace"

### Step 2: Configure Different Variables
Add **Environment Variables** (same as dev):
- `AWS_ACCESS_KEY_ID` (sensitive)
- `AWS_SECRET_ACCESS_KEY` (sensitive)
- `AWS_DEFAULT_REGION` = `us-east-2`

Add **Terraform Variables** (different from dev):
- `environment` = `staging`
- `instance_count` = `2`

### Step 3: Add Staging Tags
1. **Settings** → **General**
2. **Tags**: `environment:staging`, `team:training`

---

## 🔧 **Exercise 11.4: Test and Compare Workspaces (5 minutes)**

### Step 1: Deploy to Development
1. Switch to **lab11-development** workspace
2. In your terminal:
```bash
# Login to Terraform Cloud
terraform login

# Initialize with the development workspace
terraform init

# Select the development workspace when prompted
# Or set it explicitly:
terraform workspace select lab11-development

# Plan and apply
terraform plan
terraform apply
```

### Step 2: Deploy to Staging
1. Switch to **lab11-staging** workspace in the UI
2. In your terminal:
```bash
# Switch workspace
terraform workspace select lab11-staging

# Plan and apply
terraform plan
terraform apply
```

### Step 3: Compare Workspaces
In Terraform Cloud UI:
1. Compare the two workspaces:
   - Development: 1 instance, "development" bucket
   - Staging: 2 instances, "staging" bucket
2. Check the **Variables** tab for each
3. Look at **Tags** for organization
4. Review **State** files (they're separate)

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **Multiple Workspaces** - Created development and staging workspaces  
✅ **Workspace Variables** - Configured environment-specific variables  
✅ **Workspace Organization** - Used tags for workspace management  
✅ **CLI Integration** - Connected local Terraform to cloud workspaces  
✅ **Environment Separation** - Deployed different configurations per environment  

### Key Concepts Learned
- **Workspace Isolation**: Each workspace has its own state and variables
- **Variable Hierarchy**: Environment variables vs Terraform variables
- **Workspace Organization**: Using tags and naming conventions
- **CLI Integration**: How to work with cloud workspaces locally
- **Environment Patterns**: Different configurations for different environments

### Workspace Benefits
- **State Isolation**: No risk of accidentally affecting other environments
- **Variable Management**: Environment-specific configurations
- **Team Organization**: Clear separation of responsibilities
- **Audit Trail**: Complete history per workspace
- **Access Control**: Fine-grained permissions (available in paid tiers)

---

## 🧹 **Cleanup**
```bash
# Destroy resources in both workspaces
terraform workspace select lab11-development
terraform destroy

terraform workspace select lab11-staging
terraform destroy
```

---

## 🎓 **Next Steps**
In **Lab 12**, we'll explore **VCS integration and automated workflows** to set up GitHub-triggered Terraform Cloud deployments.

**Key topics coming up:**
- GitHub VCS integration with Terraform Cloud
- Webhook-triggered runs and automated deployments
- Pull request workflows and collaborative reviews
- GitOps patterns for infrastructure automation