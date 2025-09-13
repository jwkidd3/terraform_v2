# Lab 4: Resource Dependencies and Lifecycle Management
**Duration:** 45 minutes  
**Difficulty:** Beginner  
**Day:** 1  
**Environment:** AWS Cloud9

---

## 🎯 **Simple Learning Objectives**
By the end of this lab, you will be able to:
- Understand how Terraform manages resource dependencies
- Use `count` to create multiple similar resources
- Use `for_each` to create resources from a map
- Understand basic lifecycle rules

---

## 📋 **Prerequisites**
- Completion of Labs 2-3
- Understanding of variables and data sources

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🔗 **Exercise 4.1: Understanding Dependencies (15 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab4
cd terraform-lab4
```

### Step 2: Create main.tf with dependent resources
```hcl
# main.tf - Resources that depend on each other

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

variable "username" {
  description = "Your unique username"
  type        = string
}

# Step 1: Create an S3 bucket first
resource "aws_s3_bucket" "app_data" {
  bucket = "${var.username}-app-data-bucket"
  
  tags = {
    Name = "${var.username} App Data"
    Owner = var.username
  }
}

# Step 2: Create bucket versioning (depends on bucket)
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id  # This creates a dependency!
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Step 3: Upload a file (depends on bucket and versioning)
resource "aws_s3_object" "config" {
  bucket = aws_s3_bucket.app_data.id         # Depends on bucket
  key    = "config/app.json"
  content = jsonencode({
    username = var.username
    version  = "1.0"
    created  = timestamp()
  })
  
  # This file will only be created AFTER the bucket and versioning exist
  depends_on = [aws_s3_bucket_versioning.app_data]
  
  tags = {
    Owner = var.username
  }
}
```

### Step 3: Create terraform.tfvars
```hcl
# terraform.tfvars
username = "user1"  # Replace with your username
```

### Step 4: Deploy and Observe Dependencies
```bash
terraform init
terraform plan

# Notice the order in the plan - Terraform automatically figures out:
# 1. Create bucket first
# 2. Then create versioning 
# 3. Finally upload the file

terraform apply
```

---

## 🔢 **Exercise 4.2: Using Count (10 minutes)**

### Step 1: Add count-based resources to main.tf
Add this to the end of your `main.tf`:

```hcl
# Create multiple S3 objects using count
resource "aws_s3_object" "data_files" {
  count = 3
  
  bucket = aws_s3_bucket.app_data.id
  key    = "data/file-${count.index + 1}.txt"
  content = "This is data file number ${count.index + 1} for ${var.username}"
  
  tags = {
    Owner = var.username
    FileNumber = count.index + 1
  }
}

# Create multiple folders using count
resource "aws_s3_object" "folders" {
  count = 2
  
  bucket = aws_s3_bucket.app_data.id
  key    = "${["logs", "backups"][count.index]}/"  # Creates logs/ and backups/ folders
  content = ""  # Empty content creates a folder
  
  tags = {
    Owner = var.username
    Type = "Folder"
  }
}
```

### Step 2: Apply the changes
```bash
terraform plan
# You should see 5 new objects to be created (3 files + 2 folders)

terraform apply
```

### Step 3: Check your S3 bucket
```bash
aws s3 ls s3://${TF_VAR_username}-app-data-bucket --recursive

# You should see:
# - config/app.json
# - data/file-1.txt, file-2.txt, file-3.txt  
# - logs/ and backups/ folders
```

---

## 🗺️ **Exercise 4.3: Using for_each (15 minutes)**

### Step 1: Add for_each resources to main.tf
Add this to the end of your `main.tf`:

```hcl
# Create different file types using for_each
resource "aws_s3_object" "app_files" {
  for_each = {
    "readme"    = "README.md"
    "config"    = "config.ini" 
    "database"  = "schema.sql"
  }
  
  bucket = aws_s3_bucket.app_data.id
  key    = "app/${each.value}"
  content = "This is the ${each.key} file for ${var.username}'s application"
  
  tags = {
    Owner = var.username
    FileType = each.key
  }
}

# Create environment-specific configurations
resource "aws_s3_object" "env_configs" {
  for_each = {
    dev     = "development.json"
    staging = "staging.json"
    prod    = "production.json"
  }
  
  bucket = aws_s3_bucket.app_data.id
  key    = "environments/${each.value}"
  content = jsonencode({
    environment = each.key
    username = var.username
    debug = each.key == "dev" ? true : false
    replicas = each.key == "prod" ? 3 : 1
  })
  
  tags = {
    Owner = var.username
    Environment = each.key
  }
}
```

### Step 2: Apply the changes
```bash
terraform plan
# You should see 6 new objects (3 app files + 3 environment configs)

terraform apply
```

### Step 3: Check the new files
```bash
aws s3 ls s3://${TF_VAR_username}-app-data-bucket --recursive

# You should now see a well-organized bucket structure!
```

---

## 🔄 **Exercise 4.4: Lifecycle Rules (5 minutes)**

### Step 1: Add lifecycle rules to main.tf
Add this resource to your `main.tf`:

```hcl
# A resource with lifecycle rules
resource "aws_s3_object" "important_file" {
  bucket = aws_s3_bucket.app_data.id
  key    = "important/critical-data.txt"
  content = "This file is very important for ${var.username}!"
  
  tags = {
    Owner = var.username
    Critical = "true"
  }
  
  # Lifecycle rules
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false  # Set to true in production!
    
    # Ignore changes to content (won't update if content changes)
    ignore_changes = [content]
    
    # Create new one before destroying old one
    create_before_destroy = true
  }
}
```

### Step 2: Apply and test lifecycle
```bash
terraform apply

# Now try to change the content in the file above and apply again
# Terraform will ignore the content change due to ignore_changes
```

---

## 📤 **Exercise 4.5: Outputs for Complex Resources**

### Step 1: Create outputs.tf
```hcl
# outputs.tf - Show information about our resources

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_data.id
}

output "bucket_url" {
  description = "URL of the S3 bucket"
  value       = "https://${aws_s3_bucket.app_data.id}.s3.amazonaws.com"
}

output "data_files" {
  description = "Data files created with count"
  value       = aws_s3_object.data_files[*].key
}

output "app_files" {
  description = "App files created with for_each"
  value       = { for k, v in aws_s3_object.app_files : k => v.key }
}

output "env_configs" {
  description = "Environment config files"
  value       = { for k, v in aws_s3_object.env_configs : k => v.key }
}

output "total_objects" {
  description = "Total number of objects in bucket"
  value = (
    1 +  # config file
    length(aws_s3_object.data_files) +
    length(aws_s3_object.folders) + 
    length(aws_s3_object.app_files) +
    length(aws_s3_object.env_configs) +
    1    # important file
  )
}
```

### Step 2: View your outputs
```bash
terraform output

# See how count creates a list [file-1, file-2, file-3]
# And for_each creates a map {readme => "README.md", ...}
```

---

## 🎉 **Lab Summary**

### What You Accomplished:
✅ **Learned implicit dependencies**: S3 bucket → versioning → file upload  
✅ **Used explicit dependencies**: `depends_on` to force creation order  
✅ **Created multiple resources with count**: 3 data files, 2 folders  
✅ **Created multiple resources with for_each**: App files and environment configs  
✅ **Applied lifecycle rules**: Prevent destroy, ignore changes, create before destroy  
✅ **Built a well-organized S3 structure**: 15+ objects in logical folders  

### Key Concepts Learned:

#### **Dependencies:**
- **Implicit**: Terraform automatically detects when resources reference each other
- **Explicit**: Use `depends_on` when Terraform can't detect the dependency

#### **Count vs for_each:**
- **Count**: Creates a list of similar resources (good for simple multiples)  
- **for_each**: Creates a map of resources (good for different variations)

#### **Lifecycle Rules:**
- **prevent_destroy**: Stops accidental deletion
- **ignore_changes**: Ignores specific attribute changes
- **create_before_destroy**: Creates replacement before destroying original

---

## 🔍 **Understanding Your S3 Structure**

Your bucket now contains:
```
username-app-data-bucket/
├── config/
│   └── app.json
├── data/
│   ├── file-1.txt
│   ├── file-2.txt
│   └── file-3.txt
├── logs/
├── backups/
├── app/
│   ├── README.md
│   ├── config.ini
│   └── schema.sql
├── environments/
│   ├── development.json
│   ├── staging.json
│   └── production.json
└── important/
    └── critical-data.txt
```

**15 objects total, all created with different Terraform techniques!**

---

## 🧹 **Clean Up**

```bash
# Remove all resources
terraform destroy

# Type 'yes' when prompted
```

---

## ❓ **Troubleshooting**

### Problem: "Cycle in dependency graph"
**Solution**: You've created a circular dependency. Check your resource references.

### Problem: "Resource already exists"  
**Solution**: Another user may have the same username. Choose a different one.

### Problem: "Objects must be deleted before bucket"
**Solution**: Terraform handles this automatically due to dependencies.

---

## 🎯 **Next Steps**

In Lab 5, you'll learn:
- How to create reusable modules  
- How to organize your code into separate files
- How to share modules between different projects

**Excellent work! You now understand how Terraform manages resource relationships! 🚀**