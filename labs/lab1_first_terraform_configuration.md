# Lab 1: First Terraform Configuration (SIMPLIFIED)
**Duration:** 45 minutes  
**Difficulty:** Beginner  
**Day:** 1  
**Environment:** AWS Cloud9

---

## 🎯 **Simple Learning Objectives**
By the end of this lab, you will be able to:
- Install and verify Terraform 
- Create a basic Terraform configuration file
- Understand the basic workflow: init, plan, apply, destroy
- Create one simple AWS resource

---

## 📋 **Prerequisites**
- AWS Cloud9 environment 
- AWS credentials configured (handled by Cloud9 IAM role)

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 📝 **Exercise 1.1: Install Terraform (10 minutes)**

### Step 1: Install Terraform
```bash
# Download Terraform
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip

# Install Terraform  
sudo unzip terraform_1.6.6_linux_amd64.zip -d /usr/local/bin/
rm terraform_1.6.6_linux_amd64.zip

# Verify installation
terraform version
```

### Step 2: Test AWS Access
```bash
# Check AWS credentials work
aws sts get-caller-identity
```

---

## 🏗️ **Exercise 1.2: Create Your First Configuration (25 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab1
cd terraform-lab1
```

### Step 2: Create main.tf
Create your first Terraform file:

```hcl
# main.tf - Your first Terraform configuration

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
  region = "us-east-2"
}

# Your username variable
variable "username" {
  description = "Your unique username"
  type        = string
}

# Create an S3 bucket - this is your first AWS resource!
resource "aws_s3_bucket" "my_first_bucket" {
  bucket = "${var.username}-my-first-terraform-bucket"
  
  tags = {
    Name      = "${var.username} First Bucket"
    CreatedBy = "Terraform"
    Owner     = var.username
    Lab       = "1"
  }
}
```

### Step 3: Create terraform.tfvars
```hcl
# terraform.tfvars - Your variable values

# Replace "user1" with your actual username
username = "user1"
```

---

## ⚙️ **Exercise 1.3: Basic Terraform Workflow (10 minutes)**

### Step 1: Initialize Terraform
```bash
# This downloads the AWS provider
terraform init
```

You should see:
- "Terraform has been successfully initialized!"

### Step 2: Create a Plan
```bash
# This shows what Terraform will create
terraform plan
```

You should see:
- Plan shows 1 resource to add (the S3 bucket)

### Step 3: Apply the Configuration
```bash
# This actually creates your AWS resources
terraform apply
```

- Type `yes` when prompted
- You should see "Apply complete! Resources: 1 added"

### Step 4: Verify Your Resource
```bash
# Check your bucket exists
aws s3 ls | grep $TF_VAR_username

# You should see your bucket listed!
```

### Step 5: Destroy Your Resources
```bash
# This removes everything Terraform created
terraform destroy
```

- Type `yes` when prompted
- You should see "Destroy complete! Resources: 1 destroyed"

### Step 6: Verify Cleanup
```bash
# Check bucket is gone
aws s3 ls | grep $TF_VAR_username

# Should return nothing (bucket is deleted)
```

---

## 🎉 **Lab Summary**

### What You Accomplished:
✅ **Installed Terraform** and verified it works  
✅ **Created your first .tf file** with one simple resource  
✅ **Learned the basic workflow**: init → plan → apply → destroy  
✅ **Created an AWS S3 bucket** using Terraform  
✅ **Used variables** to make your configuration unique  
✅ **Successfully cleaned up** all resources  

### Key Files Created:
- `main.tf` - Your Terraform configuration
- `terraform.tfvars` - Your variable values
- `terraform.tfstate` - Terraform's state file (created automatically)

### Core Concepts Learned:
- **Terraform Configuration**: HCL syntax basics
- **Providers**: How to connect to AWS
- **Resources**: How to define AWS resources  
- **Variables**: How to make configurations reusable
- **State**: How Terraform tracks your resources

---

## 🔍 **Understanding What Happened**

### The Terraform Files:
1. **main.tf**: Contains your infrastructure definition
2. **terraform.tfvars**: Contains the values for your variables
3. **terraform.tfstate**: Tracks what resources exist (DO NOT EDIT)

### The Terraform Commands:
1. **terraform init**: Downloads providers and prepares your directory
2. **terraform plan**: Shows what will be created/changed/destroyed  
3. **terraform apply**: Actually makes the changes in AWS
4. **terraform destroy**: Removes all managed resources

### The AWS Resource:
- **S3 Bucket**: A simple storage container in AWS
- **Unique naming**: Used your username to avoid conflicts
- **Tags**: Labels to identify and organize your resources

---

## ❓ **Troubleshooting**

### Problem: "Error: Username variable must be set"
**Solution**: Run `export TF_VAR_username="your_username"`

### Problem: "Error: BucketAlreadyExists"  
**Solution**: Another user has the same username. Choose a different one.

### Problem: "terraform command not found"
**Solution**: Re-run the installation commands from Exercise 1.1

### Problem: "AccessDenied"
**Solution**: Check AWS credentials with `aws sts get-caller-identity`

---

## 🎯 **Next Steps**

In Lab 2, you'll learn:
- More variable types (string, number, boolean, list)
- How to use data sources to query existing AWS resources
- How to create multiple resources that work together

**Congratulations! You've completed your first Terraform lab! 🚀**