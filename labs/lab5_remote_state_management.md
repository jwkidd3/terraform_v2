# Lab 5: Remote State Management and Backend Configuration
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Implement secure remote state storage with S3 and DynamoDB
- Configure state locking to prevent concurrent modifications
- Migrate existing local state to remote backends
- Implement state encryption and versioning best practices
- Handle state backup and recovery scenarios

---

## 📋 **Prerequisites**
- Completion of Labs 1-4
- Understanding of S3 and basic AWS services
- Existing Terraform configuration with local state

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 5.1: Create Backend Infrastructure (20 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab5
cd terraform-lab5
```

### Step 2: Create Backend Infrastructure
First, we'll create the S3 bucket and DynamoDB table for secure remote state management.

**backend-setup/main.tf:**
```bash
mkdir backend-setup
cd backend-setup
```

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

locals {
  common_tags = {
    Owner       = var.username
    Purpose     = "TerraformBackend"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# S3 bucket for Terraform state with enhanced security
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.username}-terraform-state-backend"

  tags = merge(local.common_tags, {
    Name = "${var.username} Terraform State Backend"
    Type = "StateStorage"
  })
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for state security
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    
    bucket_key_enabled = true
  }
}

# Block public access completely
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "state_lifecycle"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  rule {
    id     = "abort_incomplete_uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${var.username}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "${var.username} Terraform Lock Table"
    Type = "StateLocking"
  })
}

# IAM policy for backend access (for reference)
data "aws_iam_policy_document" "terraform_backend_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "s3:ListBucket"
    ]
    
    resources = [
      aws_s3_bucket.terraform_state.arn
    ]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    
    resources = [
      aws_dynamodb_table.terraform_locks.arn
    ]
  }
}
```

**backend-setup/outputs.tf:**
```hcl
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "backend_config" {
  description = "Backend configuration for other Terraform configurations"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    region         = "us-east-2"
  }
}
```

### Step 3: Deploy Backend Infrastructure
```bash
# Initialize and deploy the backend infrastructure
terraform init
terraform apply -var="username=$TF_VAR_username"

# Save the output for use in next steps
terraform output -json > ../backend_config.json
cd ..
```

---

## 🔄 **Exercise 5.2: State Migration (15 minutes)**

### Step 1: Create Application with Local State
Let's create an application that starts with local state, then migrate it.

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
  
  # Starting with local backend - we'll change this
}

provider "aws" {
  region = "us-east-2"
}

variable "username" {
  description = "Your unique username"
  type        = string
}

# Create some resources to manage in state
resource "aws_s3_bucket" "app_storage" {
  bucket = "${var.username}-app-storage-lab5"

  tags = {
    Name        = "${var.username} Application Storage"
    Environment = "development"
    Lab         = "5"
    Owner       = var.username
  }
}

resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Create multiple objects to make state more complex
resource "aws_s3_object" "config_files" {
  for_each = {
    "app.json"    = jsonencode({
      app_name = "MyApplication"
      version  = "1.0.0"
      owner    = var.username
    })
    "settings.yaml" = <<-EOT
      database:
        host: localhost
        port: 5432
        name: myapp
      cache:
        type: redis
        ttl: 3600
    EOT
    "README.txt" = "This is application configuration for ${var.username}"
  }

  bucket       = aws_s3_bucket.app_storage.id
  key          = "config/${each.key}"
  content      = each.value
  content_type = "application/octet-stream"

  tags = {
    Type  = "ConfigFile"
    Owner = var.username
  }
}
```

**outputs.tf:**
```hcl
output "bucket_name" {
  description = "Application storage bucket name"
  value       = aws_s3_bucket.app_storage.id
}

output "config_files" {
  description = "List of configuration files created"
  value       = keys(aws_s3_object.config_files)
}

output "state_info" {
  description = "Information about current state backend"
  value = {
    backend_type = "local"
    state_file   = "${path.cwd}/terraform.tfstate"
  }
}
```

### Step 2: Deploy with Local State
```bash
# Deploy with local state first
terraform init
terraform apply -var="username=$TF_VAR_username"

# Examine the local state file
ls -la terraform.tfstate
echo "State file size: $(wc -c < terraform.tfstate) bytes"
```

### Step 3: Configure Remote Backend
Now let's migrate to remote state. Get the backend config:

```bash
# Extract backend configuration
S3_BUCKET=$(cat backend_config.json | grep -o '"bucket": "[^"]*' | cut -d'"' -f4)
DYNAMODB_TABLE=$(cat backend_config.json | grep -o '"dynamodb_table": "[^"]*' | cut -d'"' -f4)

echo "S3 Bucket: $S3_BUCKET"
echo "DynamoDB Table: $DYNAMODB_TABLE"
```

Update **main.tf** to add the backend configuration:
```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Remote backend with state locking
  backend "s3" {
    bucket         = "user1-terraform-state-backend"  # Replace with your bucket name
    key            = "lab5/application/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "user1-terraform-locks"         # Replace with your table name
    encrypt        = true
  }
}
```

### Step 4: Migrate State to Remote Backend
```bash
# Reinitialize with remote backend - Terraform will ask about migration
terraform init

# When prompted, type 'yes' to copy existing state to the new backend

# Verify remote state is working
terraform plan -var="username=$TF_VAR_username"
```

---

## 🔒 **Exercise 5.3: State Locking and Team Collaboration (10 minutes)**

### Step 1: Test State Locking
Let's verify that state locking works to prevent conflicts.

```bash
# Open a second terminal session in Cloud9
# In Terminal 1, start a long-running operation
terraform apply -var="username=$TF_VAR_username" -replace="aws_s3_bucket.app_storage"

# Quickly switch to Terminal 2 and try to run another operation
terraform plan -var="username=$TF_VAR_username"
```

You should see a message about the state being locked.

### Step 2: Examine State Lock in DynamoDB
```bash
# Check the DynamoDB table for active locks
aws dynamodb scan --table-name $DYNAMODB_TABLE --region us-east-2
```

### Step 3: State File Analysis
```bash
# Download and examine the remote state
terraform state pull > remote_state.json

# Compare with local backup (if exists)
echo "Remote state resources:"
cat remote_state.json | grep -o '"type": "[^"]*' | sort | uniq -c

# List all resources in state
terraform state list
```

---

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ Created production-ready backend infrastructure with S3 + DynamoDB
- ✅ Implemented state encryption, versioning, and lifecycle policies  
- ✅ Successfully migrated local state to secure remote backend
- ✅ Configured state locking to prevent concurrent modifications
- ✅ Tested team collaboration scenarios and conflict prevention

**Key Remote State Concepts Learned:**
- **Backend Security**: Encryption, access controls, and private buckets
- **State Locking**: DynamoDB-based locking for team environments
- **State Migration**: Safe procedures for moving from local to remote state
- **Lifecycle Management**: Cost optimization through intelligent storage tiering
- **Operational Excellence**: Monitoring, backup, and recovery considerations

**Production-Ready Features Implemented:**
- Server-side encryption with AES256
- Versioning for state history and rollback capability
- Public access blocking for security
- Lifecycle policies for cost optimization
- State locking with DynamoDB for team collaboration

**Advanced Configurations Covered:**
- Multi-environment state organization with key prefixes
- IAM policy requirements for backend access
- State file analysis and troubleshooting
- Backup and disaster recovery considerations

---

## 🧹 **Cleanup**
```bash
# Clean up application resources first
terraform destroy -var="username=$TF_VAR_username"

# Clean up backend infrastructure
cd backend-setup
terraform destroy -var="username=$TF_VAR_username"
```

Remember: In production, you typically keep the backend infrastructure running and only clean up application resources. The backend serves multiple projects and environments.