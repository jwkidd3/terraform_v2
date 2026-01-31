# Lab 6: Local State Management and Best Practices
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 2
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Understand Terraform state file structure and contents
- Implement state management best practices for shared environments
- Handle state conflicts and recovery scenarios
- Understand state locking concepts and workspace organization
- Apply state inspection and manipulation techniques safely

---

## 📋 **Prerequisites**
- Completion of Labs 2-5
- Understanding of Terraform workflow and basic resources
- Familiarity with Cloud9 shared environment concepts

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🔍 **Exercise 6.1: Understanding Terraform State (15 minutes)**

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab6
cd terraform-lab6
```

### Step 2: Create a Simple Infrastructure Configuration
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
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "username" {
  description = "Your unique username"
  type        = string
}

# S3 bucket for demonstration
resource "aws_s3_bucket" "demo" {
  bucket        = "${var.username}-state-demo-bucket"
  force_destroy = true

  tags = {
    Name        = "${var.username} State Demo"
    Owner       = var.username
    Purpose     = "StateLearning"
    Environment = "training"
  }
}

# S3 bucket versioning disabled for simplicity
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Multiple S3 objects to create more state complexity
resource "aws_s3_object" "demo_files" {
  count = 3

  bucket  = aws_s3_bucket.demo.id
  key     = "demo/file-${count.index + 1}.txt"
  content = "Demo file ${count.index + 1} for ${var.username}"

  tags = {
    Owner = var.username
    Index = count.index + 1
  }
}

# Data source to understand state dependencies
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for state inspection
locals {
  bucket_info = {
    name       = aws_s3_bucket.demo.id
    arn        = aws_s3_bucket.demo.arn
    region     = data.aws_region.current.name
    account_id = data.aws_caller_identity.current.account_id
  }
}
```

### Step 3: Initialize and Apply
```bash
terraform init
terraform plan -var="username=$TF_VAR_username"
terraform apply -var="username=$TF_VAR_username" -auto-approve
```

### Step 4: Examine the State File
```bash
# Look at the state file structure
cat terraform.tfstate | jq '.' | head -20

# List all resources in state
terraform state list

# Show details of a specific resource
terraform state show aws_s3_bucket.demo
```

**What You'll See:**
- State file contains resource metadata, attributes, and dependencies
- Each resource has a unique address in state
- Dependencies between resources are tracked

---

## 📊 **Exercise 6.2: State Inspection and Manipulation (15 minutes)**

### Step 1: Inspect State Resources
```bash
# Show all resources in state
terraform state list

# Get detailed information about the S3 bucket
terraform state show aws_s3_bucket.demo

# Show information about the versioning resource
terraform state show aws_s3_bucket_versioning.demo
```

### Step 2: Understanding State Dependencies
```bash
# Show the dependency graph
terraform graph | head -20

# Look at how count resources appear in state
terraform state show 'aws_s3_object.demo_files[0]'
terraform state show 'aws_s3_object.demo_files[1]'
terraform state show 'aws_s3_object.demo_files[2]'
```

### Step 3: State Refresh and Drift Detection
```bash
# Refresh state from actual infrastructure
terraform refresh -var="username=$TF_VAR_username"

# Plan to see if there are any differences
terraform plan -var="username=$TF_VAR_username"
```

### Step 4: Practice Safe State Operations
```bash
# Create a backup of your state file
cp terraform.tfstate terraform.tfstate.backup

# Remove a resource from state (but not from AWS)
terraform state rm 'aws_s3_object.demo_files[2]'

# Verify the resource is gone from state but still exists in AWS
terraform state list
aws s3 ls s3://${TF_VAR_username}-state-demo-bucket/ --recursive
```

---

## 🔧 **Exercise 6.3: State Recovery and Best Practices (10 minutes)**

### Step 1: Import Lost Resource
```bash
# Import the resource back into state
terraform import 'aws_s3_object.demo_files[2]' ${TF_VAR_username}-state-demo-bucket/demo/file-3.txt

# Verify it's back in state
terraform state list | grep demo_files
```

### Step 2: Understanding State in Shared Environments
Create **state-best-practices.md:**
```markdown
# Terraform State Best Practices for Shared Environments

## Key Concepts:
1. **State Isolation**: Each user works in separate directories
2. **State Backup**: Always backup state before operations
3. **State Locking**: Prevents concurrent modifications (conceptual)
4. **State Security**: State files can contain sensitive data

## Shared Environment Guidelines:
- Use unique resource naming with usernames
- Work in separate directories: ~/environment/terraform-lab6-user1/
- Never commit state files to version control
- Use .gitignore to exclude *.tfstate files
- Communicate with team about infrastructure changes

## State File Safety:
- State files may contain sensitive information
- Always use force_destroy = true for training buckets
- Keep state files secure and backed up
- Understand state file contents before sharing
```

### Step 3: Cleanup and State Verification
```bash
# Verify all resources before cleanup
terraform state list

# Plan destruction
terraform plan -destroy -var="username=$TF_VAR_username"

# Clean up all resources
terraform destroy -var="username=$TF_VAR_username" -auto-approve

# Verify state is empty
terraform state list
```

---

## 🎯 **Exercise 6.4: Advanced State Concepts (5 minutes)**

### Step 1: Create outputs.tf
```hcl
# outputs.tf - State and Infrastructure Information

output "state_info" {
  description = "Information about current state management"
  value = {
    backend_type      = "local"
    state_location    = "${path.cwd}/terraform.tfstate"
    workspace         = terraform.workspace
    state_file        = "terraform.tfstate"
  }
}

output "infrastructure_summary" {
  description = "Summary of managed infrastructure"
  value = local.bucket_info
}

output "best_practices" {
  description = "State management reminders"
  value = {
    backup_state     = "Always backup state before major operations"
    unique_naming    = "Use username prefixes for shared environments"
    state_security   = "State files may contain sensitive information"
    communication    = "Coordinate with team for shared infrastructure"
  }
}
```

### Step 2: Verify Outputs
```bash
# Apply to create outputs
terraform apply -var="username=$TF_VAR_username" -auto-approve

# Show outputs
terraform output

# Show specific output
terraform output state_info
```

---

## 📝 **Lab Completion Checklist**

- [ ] Created and examined Terraform state file structure
- [ ] Used terraform state commands for inspection
- [ ] Practiced safe state removal and import operations
- [ ] Understood state backup and recovery procedures
- [ ] Applied state management best practices for shared environments
- [ ] Successfully cleaned up all resources

---

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ **Mastered state inspection** with terraform state commands
- ✅ **Practiced state manipulation** safely with backup strategies
- ✅ **Understood shared environment** state management concepts
- ✅ **Applied state recovery techniques** with import operations
- ✅ **Learned production-ready practices** for state security and isolation

### Key Concepts Learned:
- **State Structure**: Understanding how Terraform tracks infrastructure
- **State Commands**: Using terraform state list, show, rm, and import
- **Dependency Tracking**: How Terraform manages resource relationships
- **Shared Environment Practices**: Safe state management in team settings
- **State Security**: Protecting sensitive information in state files

### Production Skills Gained:
- Infrastructure state management and troubleshooting
- Team collaboration patterns for Terraform workflows
- State backup and recovery procedures
- Resource import and state manipulation techniques

**Next Steps:**
Lab 7 will explore Terraform Registry modules and how to compose complex infrastructure using proven community modules.

---