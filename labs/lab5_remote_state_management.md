# Lab 5: Remote State Management
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. All resources will be prefixed with your username
4. State buckets and DynamoDB tables will be user-specific
5. This ensures complete isolation between users

**Example:** If your username is "user1", your resources will be named:
- `user1-terraform-state-lab-terraform-state-xxxxx` (S3 bucket)
- `user1-terraform-state-lab-lock-table` (DynamoDB table)
- State key: `user1/terraform.tfstate`

---

## Lab Objectives
By the end of this lab, you will be able to:
- Configure remote state backends in AWS
- Implement state locking with DynamoDB
- Migrate local state to remote state
- Work with multiple state files and workspaces
- Understand remote state security considerations

---

## Prerequisites
- Completion of Labs 1-4
- Understanding of Terraform modules and basic concepts
- AWS Cloud9 environment set up

---

## Exercise 5.1: Setting Up S3 Backend Infrastructure
**Duration:** 15 minutes

### Step 1: Create Lab Environment
```bash
mkdir terraform-lab5
cd terraform-lab5

# Set your username environment variable (replace YOUR_USERNAME with your actual username)
export TF_VAR_username="YOUR_USERNAME"

# Create backend setup directory
mkdir backend-setup
cd backend-setup

touch main.tf variables.tf outputs.tf terraform.tfvars
```

### Step 2: Create Backend Infrastructure
Create `terraform.tfvars` first (replace "user1" with your unique username):

```hcl
# IMPORTANT: Replace "user1" with your unique username
username = "user1"
region = "us-east-2"
project_name = "terraform-state-lab"
environment = "lab"
```

**backend-setup/variables.tf:**
```hcl
variable "username" {
  description = "Unique username for resource naming and isolation"
  type        = string
  validation {
    condition     = length(var.username) > 0 && length(var.username) <= 20
    error_message = "Username must be between 1 and 20 characters."
  }
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.username))
    error_message = "Username must start with a letter and contain only letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-state-lab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}
```

**backend-setup/main.tf:**
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
  region = var.region
}

# Generate unique suffix for bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# S3 bucket for Terraform state with username prefix
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.username}-${var.project_name}-terraform-state-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.username} Terraform State Bucket"
    Environment = var.environment
    Purpose     = "terraform-state"
    Username    = var.username
  }
}

# Configure bucket versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  depends_on = [aws_s3_bucket_versioning.terraform_state]
  
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# DynamoDB table for state locking with username prefix
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${var.username}-${var.project_name}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = var.environment
    Purpose     = "terraform-locks"
  }
}

# Optional: Create IAM policy for Terraform state access
resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.project_name}-terraform-state-policy"
  description = "IAM policy for Terraform state access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_state_lock.arn
      }
    ]
  })

  tags = {
    Name        = "Terraform State Access Policy"
    Environment = var.environment
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
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for state access"
  value       = aws_iam_policy.terraform_state_access.arn
}

output "backend_config" {
  description = "Backend configuration for use in other Terraform configurations"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = var.region
    dynamodb_table = aws_dynamodb_table.terraform_state_lock.name
    encrypt        = true
  }
}
```

### Step 3: Deploy Backend Infrastructure
```bash
# Deploy the backend infrastructure
terraform init
terraform plan
terraform apply

# Save backend configuration for later use
terraform output backend_config > ../backend-config.txt
terraform output -json > ../backend-outputs.json

# Note the S3 bucket name and DynamoDB table name
echo "S3 Bucket: $(terraform output -raw s3_bucket_name)"
echo "DynamoDB Table: $(terraform output -raw dynamodb_table_name)"
```

---

## Exercise 5.2: Configure Remote State Backend
**Duration:** 15 minutes

### Step 1: Create Application Infrastructure
```bash
# Go back to main lab directory
cd ..

# Create application infrastructure
touch main.tf variables.tf outputs.tf backend.tf
```

**variables.tf:**
```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "remote-state-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
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
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# Generate random pet name for resources
resource "random_pet" "name" {
  length = 2
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create security group
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-${var.environment}-web-"
  description = "Security group for web server"
  vpc_id      = data.aws_vpc.default.id
  
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
    cidr_blocks = ["10.0.0.0/8"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-web-sg"
    Environment = var.environment
    Project = var.project_name
  }
}

# Create EC2 instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Remote State Demo</h1>" > /var/www/html/index.html
    echo "<p>Instance: ${random_pet.name.id}</p>" >> /var/www/html/index.html
    echo "<p>Environment: ${var.environment}</p>" >> /var/www/html/index.html
  EOF
  
  tags = {
    Name = "${var.project_name}-${var.environment}-${random_pet.name.id}"
    Environment = var.environment
    Project = var.project_name
  }
}

# Create S3 bucket for application data
resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project_name}-${var.environment}-data-${random_pet.name.id}"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-app-data"
    Environment = var.environment
    Project = var.project_name
  }
}
```

**outputs.tf:**
```hcl
output "instance_info" {
  description = "EC2 instance information"
  value = {
    id         = aws_instance.web.id
    public_ip  = aws_instance.web.public_ip
    private_ip = aws_instance.web.private_ip
    dns_name   = aws_instance.web.public_dns
  }
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.web.id
}

output "app_bucket_name" {
  description = "Application data bucket name"
  value       = aws_s3_bucket.app_data.id
}

output "random_name" {
  description = "Generated random name"
  value       = random_pet.name.id
}
```

### Step 2: Configure Remote Backend
**backend.tf:**
```hcl
# Backend configuration - update with your actual values
terraform {
  backend "s3" {
    # These values will be provided during initialization
    # bucket         = "your-terraform-state-bucket-name"
    # key            = "YOUR_USERNAME/terraform.tfstate"  # Replace with your username
    # region         = "us-east-2"
    # dynamodb_table = "your-terraform-locks-table"
    # encrypt        = true
  }
}
```

### Step 3: Initialize with Local State First
```bash
# First, deploy with local state
terraform init
terraform apply

# View local state
ls -la terraform.tfstate*
terraform state list
```

### Step 4: Migrate to Remote State
```bash
# Get backend values from the previous step
S3_BUCKET=$(cat backend-outputs.json | jq -r '.backend_config.value.bucket')
DYNAMODB_TABLE=$(cat backend-outputs.json | jq -r '.backend_config.value.dynamodb_table')

echo "S3 Bucket: $S3_BUCKET"
echo "DynamoDB Table: $DYNAMODB_TABLE"

# Initialize with remote backend
terraform init \
  -backend-config="bucket=$S3_BUCKET" \
  -backend-config="key=${TF_VAR_username}/terraform.tfstate" \
  -backend-config="region=us-east-2" \
  -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
  -backend-config="encrypt=true" \
  -migrate-state

# Verify state migration
terraform state list

# Local state should be backed up
ls -la terraform.tfstate*
```

---

## Exercise 5.3: Working with Remote State
**Duration:** 15 minutes

### Step 1: Test Remote State Functionality
```bash
# Make a change to test remote state
terraform plan -var="instance_type=t2.small"
terraform apply -var="instance_type=t2.small"

# Verify state is stored remotely
aws s3 ls s3://$S3_BUCKET/dev/
aws s3 cp s3://$S3_BUCKET/dev/terraform.tfstate - | jq '.resources[0].type'
```

### Step 2: Create Multiple Environments with Workspaces
```bash
# Create staging workspace
terraform workspace new staging

# List workspaces
terraform workspace list

# Deploy to staging
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"

# Switch back to default workspace
terraform workspace select default

# List resources in each workspace
terraform workspace select default
terraform state list

terraform workspace select staging  
terraform state list

# Check S3 bucket structure
aws s3 ls s3://$S3_BUCKET/
aws s3 ls s3://$S3_BUCKET/env:/
```

### Step 3: State Locking Demonstration
```bash
# In one terminal, start a long-running operation
terraform apply -var="environment=staging-locked" &

# In another terminal/tab, try to run plan (should be locked)
# This will fail with a state lock error
terraform plan
```

### Step 4: Remote State Data Source
Create a new configuration that references the remote state:

**Create new directory:**
```bash
mkdir terraform-lab5-consumer
cd terraform-lab5-consumer

touch main.tf outputs.tf
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
  }
}

provider "aws" {
  region = "us-east-2"
}

# Reference remote state from another configuration
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "${var.username}/terraform.tfstate"
    region = "us-east-2"
  }
}

# Create a resource that depends on the remote state
resource "aws_security_group_rule" "additional_access" {
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  cidr_blocks             = ["0.0.0.0/0"]
  security_group_id       = data.terraform_remote_state.infrastructure.outputs.security_group_id
  description             = "HTTPS access added by consumer"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket containing Terraform state"
  type        = string
}
```

**outputs.tf:**
```hcl
output "referenced_instance_id" {
  description = "Instance ID from remote state"
  value       = data.terraform_remote_state.infrastructure.outputs.instance_info.id
}

output "referenced_bucket_name" {
  description = "Bucket name from remote state"
  value       = data.terraform_remote_state.infrastructure.outputs.app_bucket_name
}
```

```bash
# Deploy consumer configuration
terraform init
terraform apply -var="state_bucket_name=$S3_BUCKET"

# View outputs
terraform output
```

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Remote State Setup:**
   - S3 bucket configuration for state storage
   - DynamoDB table for state locking
   - Security and lifecycle configurations

2. **State Migration:**
   - Migrating from local to remote state
   - Backend configuration options
   - State backup and recovery

3. **Workspaces:**
   - Creating and managing multiple environments
   - Workspace-specific state files
   - Switching between workspaces

4. **Remote State References:**
   - Using terraform_remote_state data source
   - Cross-configuration dependencies
   - State sharing between teams

### Best Practices Demonstrated

- Enable versioning and encryption for state buckets
- Use state locking to prevent concurrent modifications
- Implement lifecycle policies for state file cleanup
- Use descriptive keys for state file organization
- Create IAM policies for controlled state access

### Security Considerations

- State files can contain sensitive information
- Use encryption at rest and in transit
- Implement proper IAM permissions
- Regular backup and monitoring
- Consider using Terraform Cloud for enhanced security

### Clean Up
```bash
# Clean up consumer resources
terraform destroy -var="state_bucket_name=$S3_BUCKET"

# Go back to main lab
cd ../terraform-lab5

# Clean up staging workspace
terraform workspace select staging
terraform destroy -var="environment=staging"

# Clean up default workspace
terraform workspace select default
terraform destroy

# Clean up backend infrastructure
cd backend-setup
terraform destroy
```

---

## Next Steps
In Lab 6, you'll learn about:
- Terraform Cloud integration
- Remote operations and policy enforcement
- Team collaboration features
- Cost estimation and compliance

---

## Troubleshooting

### Common Issues

1. **State Lock Errors:**
   ```bash
   # Force unlock (use with extreme caution)
   terraform force-unlock LOCK_ID
   ```

2. **Backend Migration Issues:**
   ```bash
   # Reconfigure backend
   terraform init -reconfigure
   ```

3. **State File Corruption:**
   ```bash
   # Pull state from remote
   terraform state pull > backup.tfstate
   ```

4. **Workspace Issues:**
   ```bash
   # List all workspaces
   terraform workspace list
   
   # Delete workspace (must be empty)
   terraform workspace delete workspace_name
   ```