# Lab 10: Terraform Cloud Integration and Remote Execution
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Set up and configure Terraform Cloud for enterprise workflow management
- Migrate existing infrastructure to Terraform Cloud with remote execution
- Implement secure variable management and workspace configuration
- Configure automated runs with VCS integration and approval workflows
- Monitor infrastructure changes and collaborate effectively using Terraform Cloud

---

## 📋 **Prerequisites**
- Completion of Labs 1-9
- Terraform Cloud account (free tier sufficient)
- Understanding of state management from Lab 6
- GitHub account for VCS integration

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## ☁️ **Exercise 10.1: Terraform Cloud Organization Setup (15 minutes)**

### Step 1: Create Terraform Cloud Organization
1. Go to https://app.terraform.io/
2. Sign up or sign in to your account
3. Create a new organization: `${username}-terraform-training`
4. Note your organization name for later use

### Step 2: Create Lab Directory and Configuration
```bash
cd ~/environment
mkdir terraform-lab10
cd terraform-lab10
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

  cloud {
    organization = "user1-terraform-training"  # Replace with your org name

    workspaces {
      name = "user1-terraform-cloud-lab10"      # Replace with your username
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

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "terraform-cloud"
}

locals {
  name_prefix = "${var.username}-${var.environment}"

  common_tags = {
    Owner       = var.username
    Environment = var.environment
    ManagedBy   = "TerraformCloud"
    Lab         = "10"
  }
}

# EC2 instance
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "demo" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Terraform Cloud Demo - ${var.username}</h1>" > /var/www/html/index.html
    echo "<p>Managed by Terraform Cloud</p>" >> /var/www/html/index.html
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-demo-instance"
  })
}
```

### Step 3: Create Outputs File
Create **outputs.tf:**

```hcl
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.demo.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.demo.public_ip
}

output "terraform_cloud_workspace" {
  description = "Terraform Cloud workspace information"
  value = {
    workspace_name = "${var.username}-terraform-cloud-lab10"   # Replace with your values
    organization   = "${var.username}-terraform-training"      # Replace with your values
    execution_mode = "remote"
  }
}
```

---

## 🔧 **Exercise 10.2: Workspace Configuration and Remote Execution (20 minutes)**

### Step 1: Create Terraform Cloud Workspace
1. In Terraform Cloud UI, go to your organization
2. Click "New workspace"
3. Choose "CLI-driven workflow"
4. Name: `${username}-terraform-cloud-lab10`
5. Description: "Lab 10 - Terraform Cloud Integration"
6. Click "Create workspace"

### Step 2: Configure Workspace Variables
In your Terraform Cloud workspace, add these environment variables:
- `AWS_ACCESS_KEY_ID` (sensitive) - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` (sensitive) - Your AWS secret key  
- `AWS_DEFAULT_REGION` - `us-east-2`

Add these Terraform variables:
- `username` - Your username (e.g., "user1")

### Step 3: Execute Remote Plans and Applies
```bash
# Authenticate with Terraform Cloud
terraform login

# Initialize with cloud backend
terraform init

# Create a plan (runs remotely in Terraform Cloud)
terraform plan

# Apply the changes (runs remotely in Terraform Cloud)
terraform apply

# Check outputs
terraform output
```

### Step 4: Monitor Remote Execution
1. Go to your Terraform Cloud workspace
2. Watch the run in progress
3. Review execution logs in real-time
4. Examine the plan details and resource changes
5. Approve the apply when prompted

---

## 🚀 **Exercise 10.3: Explore Terraform Cloud Features (10 minutes)**

### Step 1: Test Terraform Cloud Features
1. **State Management**: View state versions in Terraform Cloud UI
2. **Run Details**: Review plan output and apply status
3. **Variable Management**: Update variables through the UI
4. **Run History**: Review previous runs and changes

### Step 2: Test Your Resources
```bash
# Check outputs
terraform output

# Test the web server
curl http://$(terraform output -raw instance_public_ip)
```

### Step 3: Workspace Settings
1. **General Settings**:
   - Auto Apply: Keep manual for learning
   - Terraform Version: Note the version used
2. **Variables**:
   - Review environment vs Terraform variables
   - Update username variable if needed

---

## 🔍 **Exercise 10.4: Troubleshooting and Best Practices (5 minutes)**

### Step 1: Common Terraform Cloud Issues
Test these scenarios:
```bash
# Trigger a plan with an intentional error
# Add invalid configuration to main.tf temporarily
terraform plan

# Review error handling in Terraform Cloud UI
# Fix the error and re-run
```

### Step 2: Best Practices Demonstrated
Review what you've implemented:
- ✅ **Variable Security**: Sensitive variables marked as sensitive
- ✅ **Resource Tagging**: Consistent tagging strategy
- ✅ **Remote State**: Centralized state management
- ✅ **Workspace Isolation**: Separate workspace for different purposes
- ✅ **Version Pinning**: Terraform and provider versions specified

---

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ **Terraform Cloud Setup**: Created organization and configured remote execution workspace
- ✅ **Remote Infrastructure Management**: Deployed EC2 instance via Terraform Cloud
- ✅ **Secure Variable Management**: Implemented proper credential and variable storage
- ✅ **Enterprise Workflow**: Established foundation for team collaboration and governance
- ✅ **Advanced Features**: Explored run history, state management, and workspace features

**Key Terraform Cloud Concepts:**
- **Remote Execution**: All Terraform operations run in Terraform Cloud, not locally
- **State Management**: Centralized, versioned state storage with automatic locking
- **Workspace Isolation**: Separate execution environments for different infrastructure
- **Variable Security**: Encrypted storage of sensitive variables and credentials
- **Collaboration Foundation**: Team-ready configuration with proper access controls

**Enterprise Features Demonstrated:**
- Cloud-based execution environment with consistent Terraform versions
- Automatic state versioning and backup
- Remote plan and apply execution with detailed logs
- Complete audit trail of all infrastructure modifications
- Secure credential management
- Workspace-based organization for team collaboration

**Production-Ready Patterns:**
- EC2 instance with user data configuration
- Comprehensive resource tagging strategy
- Remote state management via Terraform Cloud

**Benefits Over Local Execution:**
- Consistent execution environment across team members
- Centralized state management eliminates state conflicts
- Automatic backups and version history
- Integrated security scanning and policy enforcement
- Detailed plan output showing resource changes
- Complete audit trail for compliance requirements

---

## 🧹 **Cleanup**
```bash
# Destroy infrastructure via Terraform Cloud (runs remotely)
terraform destroy

# Confirm destruction in Terraform Cloud UI
# Review the destroy plan before approving
```

This lab demonstrates the enterprise advantages of Terraform Cloud, providing centralized state management, remote execution, and the foundation for team collaboration while maintaining the same infrastructure-as-code principles you've learned throughout the course.

---

## ➡️ **Next Steps**
Continue to **Lab 11**, which covers Terraform Cloud workspaces in greater depth, including multi-environment management and workspace strategies for team collaboration.