# Lab 9: Introduction to Terraform Cloud
**Duration:** 45 minutes  
**Difficulty:** Beginner to Intermediate  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. Create your own Terraform Cloud organization
4. All workspaces and resources will be prefixed with your username
5. This ensures complete isolation between users

**Example:** If your username is "user1", your resources will be named:
- Terraform Cloud Organization: `user1-terraform-lab`
- Workspace: `user1-terraform-cloud-demo`
- AWS resources: `user1-` prefixed

---

## Lab Objectives
By the end of this lab, you will be able to:
- Create a Terraform Cloud account and organization
- Understand the benefits of Terraform Cloud over local execution
- Migrate local state to Terraform Cloud
- Configure workspace variables and settings
- Execute remote runs in Terraform Cloud
- Understand the basics of Terraform Cloud workflow

---

## Prerequisites
- Completion of Labs 1-8
- AWS Cloud9 environment set up
- Basic understanding of Terraform configuration
- Email address for Terraform Cloud account

---

## Exercise 9.1: Getting Started with Terraform Cloud
**Duration:** 15 minutes

### Step 1: Create Terraform Cloud Account
```bash
# Navigate to https://app.terraform.io/signup/account
# Create a free account (supports up to 5 users)
# Verify your email address
# Log into Terraform Cloud
```

### Step 2: Create Your First Organization
```bash
# In Terraform Cloud UI:
# 1. Click "Create new organization"
# 2. Choose a unique organization name (e.g., yourname-training)
# 3. Enter your email address
# 4. Click "Create organization"
```

### Step 3: Generate API Token
```bash
# In Terraform Cloud UI:
# 1. Click your avatar → User Settings
# 2. Click "Tokens" in the left sidebar
# 3. Click "Create an API token"
# 4. Name it "cloud9-cli-token"
# 5. Copy the token immediately (shown only once!)
```

### Step 4: Configure Terraform CLI
```bash
# In your Cloud9 terminal
cd ~
mkdir -p ~/.terraform.d

# Create credentials file
cat > ~/.terraform.d/credentials.tfrc.json << 'EOF'
{
  "credentials": {
    "app.terraform.io": {
      "token": "YOUR_API_TOKEN_HERE"
    }
  }
}
EOF

# Set proper permissions
chmod 600 ~/.terraform.d/credentials.tfrc.json

# Verify token is configured
terraform login
# Should show "Terraform has obtained and saved an API token"
```

---

## Exercise 9.2: Migrating from Local to Remote State
**Duration:** 15 minutes

### Step 1: Create Project with Local State
```bash
# Create new project directory
cd ~
mkdir terraform-cloud-intro
cd terraform-cloud-intro

# Create initial configuration with local state
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 bucket for demonstration
resource "aws_s3_bucket" "example" {
  bucket = "tfc-demo-${random_id.suffix.hex}"
  
  tags = {
    Name        = "Terraform Cloud Demo"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# EC2 instance
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  tags = {
    Name        = "tfc-demo-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform Cloud"
  }
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
EOF
```

### Step 2: Create Variables File
```bash
cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
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
EOF

cat > outputs.tf << 'EOF'
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.example.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.example.arn
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.example.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.example.public_ip
}

output "state_location" {
  description = "Location of Terraform state"
  value       = "Local state file"
}
EOF
```

### Step 3: Initialize and Apply with Local State
```bash
# Initialize with local backend
terraform init

# Create initial infrastructure
terraform plan
terraform apply -auto-approve

# Verify local state exists
ls -la terraform.tfstate
cat terraform.tfstate | jq '.version'

# Save the state file for comparison
cp terraform.tfstate terraform.tfstate.backup
```

### Step 4: Migrate to Terraform Cloud
```bash
# Update configuration to use Terraform Cloud
cat > backend.tf << 'EOF'
terraform {
  cloud {
    organization = "YOUR_ORG_NAME"  # Replace with your organization
    
    workspaces {
      name = "getting-started"
    }
  }
}
EOF

# Reinitialize with Terraform Cloud backend
terraform init

# When prompted:
# "Do you want to copy existing state to the new backend?"
# Type: yes

# Verify migration successful
echo "State has been migrated to Terraform Cloud!"

# Local state file should now be empty
cat terraform.tfstate
# Should show: {"version": 4, "terraform_version": "...", "serial": 1, "lineage": "...", "outputs": {}, "resources": []}
```

---

## Exercise 9.3: Working with Terraform Cloud Workspaces
**Duration:** 15 minutes

### Step 1: Configure Workspace in UI
```bash
# In Terraform Cloud UI:
# 1. Navigate to your organization
# 2. Click on "getting-started" workspace
# 3. Go to "Variables" tab
```

### Step 2: Set Environment Variables
```bash
# In the Variables tab, add Environment Variables:
# 1. Click "Add variable"
# 2. Select "Environment variable"
# 3. Add these variables:

# AWS_ACCESS_KEY_ID
# - Key: AWS_ACCESS_KEY_ID
# - Value: [Your AWS Access Key]
# - Sensitive: ✓

# AWS_SECRET_ACCESS_KEY
# - Key: AWS_SECRET_ACCESS_KEY  
# - Value: [Your AWS Secret Key]
# - Sensitive: ✓

# AWS_DEFAULT_REGION
# - Key: AWS_DEFAULT_REGION
# - Value: us-east-2
# - Sensitive: ✗
```

### Step 3: Set Terraform Variables
```bash
# Still in Variables tab, add Terraform Variables:
# 1. Click "Add variable"
# 2. Select "Terraform variable"

# environment
# - Key: environment
# - Value: dev
# - HCL: ✗
# - Sensitive: ✗

# instance_type
# - Key: instance_type
# - Value: t2.micro
# - HCL: ✗
# - Sensitive: ✗
```

### Step 4: Execute Remote Runs
```bash
# Make a change to trigger a run
cat >> main.tf << 'EOF'

# Add a new tag to demonstrate changes
resource "aws_s3_bucket_tagging" "example" {
  bucket = aws_s3_bucket.example.id
  
  tags = {
    Team        = "DevOps"
    CostCenter  = "Engineering"
    Project     = "TerraformCloudDemo"
  }
}
EOF

# Update outputs to show state location
cat > outputs.tf << 'EOF'
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.example.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.example.arn
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.example.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.example.public_ip
}

output "state_location" {
  description = "Location of Terraform state"
  value       = "Terraform Cloud - Organization: ${var.organization_name}"
}

output "workspace_url" {
  description = "URL to view this workspace in Terraform Cloud"
  value       = "https://app.terraform.io/app/${var.organization_name}/workspaces/getting-started"
}
EOF

# Add organization variable
cat >> variables.tf << 'EOF'

variable "organization_name" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "YOUR_ORG_NAME"  # Replace with your org
}
EOF

# Plan and apply changes
terraform plan
# This will now run remotely in Terraform Cloud!

# Watch the run in the UI
echo "Open Terraform Cloud UI to watch the run progress"
echo "https://app.terraform.io/app/YOUR_ORG_NAME/workspaces/getting-started/runs"

# Apply the changes
terraform apply
# Type: yes when prompted
```

### Step 5: Explore Terraform Cloud Features
```bash
# In Terraform Cloud UI, explore:

# 1. Runs tab
#    - View run history
#    - See plan/apply logs
#    - Check run status

# 2. States tab
#    - Browse state versions
#    - Download state files
#    - View state outputs

# 3. Variables tab
#    - Review configured variables
#    - Note sensitive variable masking

# 4. Settings tab
#    - General settings
#    - Locking
#    - Notifications
#    - Run triggers

# 5. Overview tab
#    - Resources managed
#    - Recent runs
#    - README display (if configured)
```

---

## Understanding Terraform Cloud Benefits

### 1. Remote State Management
```bash
# Create a comparison document
cat > terraform-cloud-benefits.md << 'EOF'
# Terraform Cloud Benefits Demonstrated

## 1. Remote State Storage
- **Before:** State stored locally in terraform.tfstate
- **After:** State stored securely in Terraform Cloud
- **Benefit:** Team collaboration, state locking, versioning

## 2. Remote Execution
- **Before:** terraform plan/apply runs on local machine
- **After:** Runs execute in Terraform Cloud's secure environment
- **Benefit:** Consistent environment, no local credentials needed

## 3. Variable Management
- **Before:** Variables in .tfvars files or environment
- **After:** Centralized variable management in UI
- **Benefit:** Secure storage, easy updates, audit trail

## 4. Access Control
- **Before:** Anyone with state file has full access
- **After:** Role-based access control (RBAC)
- **Benefit:** Granular permissions, team management

## 5. Run History
- **Before:** No history beyond local terminal output
- **After:** Complete history of all runs
- **Benefit:** Audit trail, debugging, compliance

## 6. State Locking
- **Before:** Manual locking or conflicts
- **After:** Automatic state locking
- **Benefit:** Prevents concurrent modifications

## 7. Cost Estimation
- **Available in paid tiers**
- Shows estimated costs before apply
- Helps prevent budget overruns
EOF

cat terraform-cloud-benefits.md
```

### 2. Compare Local vs Remote Workflows
```bash
# Create workflow comparison
cat > workflow-comparison.md << 'EOF'
# Terraform Workflow Comparison

## Local Workflow
1. Write Terraform configuration
2. Set AWS credentials locally
3. Run: terraform init
4. Run: terraform plan
5. Run: terraform apply
6. State saved locally
7. Share state file manually for team

## Terraform Cloud Workflow
1. Write Terraform configuration
2. Configure credentials in Terraform Cloud (once)
3. Run: terraform init (connects to TFC)
4. Run: terraform plan (executes remotely)
5. Run: terraform apply (executes remotely)
6. State saved in Terraform Cloud
7. Team automatically has access

## Key Differences
- **Security:** Credentials never on local machine
- **Consistency:** Same execution environment
- **Collaboration:** Built-in team features
- **History:** Complete audit trail
- **Automation:** Triggers, notifications, policies
EOF

cat workflow-comparison.md
```

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Terraform Cloud Basics:**
   - Account and organization creation
   - API token configuration
   - Workspace concepts

2. **State Migration:**
   - Migrating from local to remote state
   - Understanding backend configuration
   - State file management in Terraform Cloud

3. **Remote Execution:**
   - Running plans and applies remotely
   - Viewing run output in UI
   - Understanding run queues

4. **Variable Management:**
   - Environment vs Terraform variables
   - Sensitive variable handling
   - Variable precedence

5. **Core Benefits:**
   - Team collaboration features
   - Security improvements
   - Audit and compliance capabilities

### Clean Up Resources
```bash
# Destroy the infrastructure
terraform destroy
# Type: yes when prompted

# The destroy will also run remotely in Terraform Cloud
# Watch progress in the UI
```

### Best Practices Learned

1. **Always use remote state** for team environments
2. **Never commit credentials** to version control
3. **Use Terraform Cloud** for consistent execution
4. **Configure variables** in workspace, not in code
5. **Review plans** before applying changes

---

## Next Steps
In Lab 10, you'll learn about:
- Advanced workspace management
- Team collaboration and RBAC
- Variable sets and workspace relationships
- Run triggers and automation

---

## Troubleshooting

### Common Issues and Solutions

1. **API Token Issues**
   ```bash
   # Verify token is set correctly
   cat ~/.terraform.d/credentials.tfrc.json
   
   # Re-run login if needed
   terraform login
   ```

2. **Organization Name Mismatch**
   ```bash
   # Ensure organization name in backend.tf matches your actual org
   # Update backend.tf with correct org name
   ```

3. **AWS Credentials Not Working**
   ```bash
   # In Terraform Cloud UI:
   # - Verify variables are set as "Environment" not "Terraform"
   # - Ensure sensitive checkbox is checked
   # - Try re-entering credentials
   ```

4. **State Migration Failed**
   ```bash
   # If migration fails:
   terraform init -reconfigure
   # This forces backend reconfiguration
   ```

5. **Remote Run Not Starting**
   ```bash
   # Check in UI:
   # - Workspace → Settings → General
   # - Ensure "Execution Mode" is "Remote"
   # - Check run queue isn't blocked
   ```

### Getting Help
- [Terraform Cloud Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [Terraform Cloud Learn Tutorials](https://developer.hashicorp.com/terraform/tutorials/cloud-get-started)
- [Community Forum](https://discuss.hashicorp.com/c/terraform-core)