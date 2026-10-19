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
# Your username was saved by setup.sh in Lab 1 — confirm it is set
echo "Username: $TF_VAR_username"
```

> If it prints nothing, run `source ~/.bashrc`. If it shows the wrong name, re-run `bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <your-username>` and then `source ~/.bashrc`. Do **not** `export` a different value — every resource name includes it.

> **Note:** `username` comes **only** from `TF_VAR_username` — do not add it to `terraform.tfvars` (a value there would override the environment variable). All resources deploy to **us-east-2**, the default of the `aws_region` variable, so there is no region to set.

---

## 🔍 **Exercise 6.1: Understanding Terraform State (15 minutes)**

### Step 1: Navigate to Lab Directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab06
```

### Step 2: Review the Infrastructure Configuration
The configuration is already provided in the lab directory. Review `main.tf` (you will examine `outputs.tf` in Exercise 6.4):

**main.tf:**
```hcl
terraform {
  required_version = ">= 1.9"

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

provider "aws" {
  region = var.aws_region
}

variable "username" {
  description = "Your unique username"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters: lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

# Random suffix - S3 bucket names are global across ALL AWS accounts
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for demonstration
resource "aws_s3_bucket" "demo" {
  bucket        = "${var.username}-state-demo-bucket-${random_id.bucket_suffix.hex}"
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
    Index = tostring(count.index + 1)
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
terraform plan
terraform apply -auto-approve
```

> `username` comes from `TF_VAR_username` automatically, so no `-var` flag is needed.

The plan should show `Plan: 6 to add, 0 to change, 0 to destroy.` (the random suffix, the bucket, its versioning configuration, and three objects). The bucket name ends with a random suffix because S3 bucket names are global across all AWS accounts — read the full name at any time with `terraform output -raw bucket_name`.

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
# Compare state with the real infrastructure, then update state
terraform apply -refresh-only

# Plan to see if there are any differences
terraform plan
```

`terraform apply -refresh-only` reads every resource from AWS and shows any differences between the real infrastructure and your state **before** changing anything. If it finds differences it asks you to type `yes` before recording them in state; it never creates, changes, or destroys resources. Nothing has drifted yet, so expect `No changes. Your infrastructure still matches the configuration.` with no prompt. It replaces the older `terraform refresh` command, which is deprecated because it rewrote state silently, without showing you what changed.

### Step 4: Practice Safe State Operations
```bash
# Create a backup of your state file
# (use a distinct name — Terraform overwrites terraform.tfstate.backup itself)
cp terraform.tfstate terraform.tfstate.manual-backup

# Remove a resource from state (but not from AWS)
terraform state rm 'aws_s3_object.demo_files[2]'

# Verify the resource is gone from state but still exists in AWS
terraform state list
aws s3 ls s3://$(terraform output -raw bucket_name)/ --recursive
```

---

## 🔧 **Exercise 6.3: State Recovery and Best Practices (10 minutes)**

### Step 1: Import Lost Resource
```bash
# Import the resource back into state
# (the import ID for an S3 object is <bucket name>/<key>)
terraform import 'aws_s3_object.demo_files[2]' $(terraform output -raw bucket_name)/demo/file-3.txt

# Verify it's back in state
terraform state list | grep demo_files
```

### Step 2: Understanding State in Shared Environments
Create **state-best-practices.md:**
```markdown
# Terraform State Best Practices for Shared Environments

## Key Concepts:
1. **State Isolation**: Each student works in their own environment and lab directory
2. **State Backup**: Always backup state before operations
3. **State Locking**: Prevents concurrent modifications (conceptual)
4. **State Security**: State files can contain sensitive data

## Shared Environment Guidelines:
- Use unique resource naming with usernames
- Each student has their own Cloud9 environment and works in its own copy of the lab (`~/environment/terraform_v2/lab-exercises/lab06`), so local state files are never shared
- Never commit state files to version control
- Use .gitignore to exclude *.tfstate files
- Communicate with team about infrastructure changes

## State File Safety:
- State files may contain sensitive information
- Always use force_destroy = true for training buckets
- Keep state files secure and backed up
- Understand state file contents before sharing
```

---

## 🎯 **Exercise 6.4: Advanced State Concepts (5 minutes)**

### Step 1: Review outputs.tf
`outputs.tf` has been in the lab directory since Exercise 6.1, so its values were recorded in state by your first `terraform apply`:

```hcl
# outputs.tf - State and Infrastructure Information

output "state_info" {
  description = "Information about current state management"
  value = {
    backend_type   = "local"
    state_location = "${path.cwd}/terraform.tfstate"
    workspace      = terraform.workspace
    state_file     = "terraform.tfstate"
  }
}

output "bucket_name" {
  description = "Name of the demo S3 bucket (includes a random suffix)"
  value       = aws_s3_bucket.demo.id
}

output "infrastructure_summary" {
  description = "Summary of managed infrastructure"
  value       = local.bucket_info
}

output "best_practices" {
  description = "State management reminders"
  value = {
    backup_state   = "Always backup state before major operations"
    unique_naming  = "Use username prefixes for shared environments"
    state_security = "State files may contain sensitive information"
    communication  = "Coordinate with team for shared infrastructure"
  }
}
```

> **Key Concept:** Output values live in the state file alongside resources. `terraform output` reads them straight from state — it does not contact AWS — which is why other tools and scripts can rely on it.

### Step 2: Verify Outputs
```bash
# Show all outputs
terraform output

# Show specific output
terraform output state_info

# Print a single raw value (used by the commands earlier in this lab)
terraform output -raw bucket_name

# Outputs are stored in the state file itself
jq '.outputs | keys' terraform.tfstate
```

---

## 🧹 **Cleanup and State Verification**

Destroy everything this lab created so nothing is left running in the shared account:

```bash
# Verify all resources before cleanup
terraform state list

# Plan destruction
terraform plan -destroy

# Clean up all resources
terraform destroy -auto-approve

# Verify state is empty
terraform state list

# Verify the bucket is gone
aws s3 ls | grep "${TF_VAR_username}-state-demo"
```

`terraform destroy` should report `Destroy complete! Resources: 6 destroyed.`, and both of the last two commands should return nothing.

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