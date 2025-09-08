# Lab 1: First Terraform Configuration
**Duration:** 45 minutes  
**Difficulty:** Beginner  
**Day:** 1  
**Environment:** AWS Cloud9

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. All resources will be prefixed with your username
4. This ensures isolated resources for each user

**Example:** If your username is "user1", your resources will be named:
- `user1-` prefixed resources
- `user1/terraform.tfstate` state file path
- `user1-vpc`, `user1-instance`, etc.

---

## Lab Objectives
By the end of this lab, you will be able to:
- Set up Terraform in AWS Cloud9 environment
- Create your first basic Terraform configuration
- Understand the basic Terraform workflow (init, plan, apply)
- Work with simple resources and random providers

---

## Prerequisites
- AWS Cloud9 environment set up
- AWS credentials configured (handled by Cloud9 IAM role)
- Basic familiarity with terminal/command line

---

## Exercise 1.1: Cloud9 Environment Setup
**Duration:** 10 minutes

### Step 1: Install Terraform in Cloud9
```bash
# Download and install Terraform
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
sudo unzip terraform_1.6.6_linux_amd64.zip -d /usr/local/bin/
rm terraform_1.6.6_linux_amd64.zip

# Verify installation
terraform version
```

### Step 2: Verify AWS Access
```bash
# Cloud9 automatically configures AWS credentials
# Verify access
aws sts get-caller-identity

# You should see your AWS account details
```

### Step 3: Create Lab Directory
```bash
# Create and navigate to lab directory (replace USERNAME with your chosen username)
export TF_USERNAME="USERNAME"  # Replace USERNAME with your actual username
mkdir terraform-lab1
cd terraform-lab1

# Create initial files
touch main.tf
touch variables.tf
touch outputs.tf
touch terraform.tfvars

# Verify setup
ls -la
```

---

## Exercise 1.2: Your First Terraform Resource
**Duration:** 20 minutes

### Step 1: Create a Simple Random Resource
Create your first Terraform configuration using the `random` provider (no cloud credentials needed):

**File: variables.tf**
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
```

**File: terraform.tfvars** (Update with your username)
```hcl
# Replace "user1" with your unique username
username = "user1"
```

**File: main.tf**
```hcl
# Configure Terraform and required providers
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  # Note: Backend configuration will be set during terraform init
  # State file will be isolated per user
}

# Generate a random pet name with username prefix
resource "random_pet" "server_name" {
  length    = 2
  separator = "-"
  prefix    = var.username
}

# Generate a random password
resource "random_password" "admin_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}
```

### Step 2: Initialize Terraform with User-Specific State
```bash
# Set your username first (replace YOUR_USERNAME with your actual username)
export TF_VAR_username="YOUR_USERNAME"

# Initialize the working directory with user-specific state file
terraform init -backend-config="path=terraform-${TF_VAR_username}.tfstate"

# Expected output:
# - Downloads and installs the random provider
# - Creates .terraform directory
# - Creates .terraform.lock.hcl file
# - Sets up user-specific state file path
```

**What happened?**
- Terraform downloaded the `random` provider
- Created a `.terraform` directory with provider plugins
- Generated a lock file to ensure consistent provider versions

### Step 3: Create an Execution Plan
```bash
# Generate and show execution plan
terraform plan

# Expected output:
# Plan: 2 to add, 0 to change, 0 to destroy.
```

**Examine the plan output:**
- **Green (+):** Resources to be created
- **Yellow (~):** Resources to be modified  
- **Red (-):** Resources to be destroyed

### Step 4: Apply the Configuration
```bash
# Apply the changes
terraform apply

# When prompted, type 'yes' to confirm
```

**What happened?**
- Terraform created the random resources
- Generated a `terraform.tfstate` file to track resources
- Displayed the output values

### Step 5: Inspect the Results
```bash
# Show current state
terraform show

# List resources in state
terraform state list

# Show specific resource
terraform state show random_pet.server_name
```

---

## Exercise 1.3: Add an AWS Resource
**Duration:** 15 minutes

### Step 1: Add AWS Provider Configuration
Replace your existing `main.tf` content with:

```hcl
# Configure Terraform and providers
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Note: Backend configuration will be set during terraform init
  # State file will be isolated per user
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"  # Using us-east-2 for simplicity
}

# Generate a random pet name with username prefix
resource "random_pet" "server_name" {
  length    = 2
  separator = "-"
  prefix    = var.username
}

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create an EC2 instance with username prefix
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  
  tags = {
    Name        = "${var.username}-${random_pet.server_name.id}"
    Environment = "lab"
    ManagedBy   = "Terraform"
    Lab         = "1"
    Username    = var.username
  }
}
```

### Step 2: Define Outputs
Update your `outputs.tf` file:

```hcl
output "username" {
  description = "The username used for this deployment"
  value       = var.username
}

output "server_name" {
  description = "The generated server name with username prefix"
  value       = random_pet.server_name.id
}

output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.web_server.id
}

output "instance_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "resource_tags" {
  description = "Tags applied to the instance showing username"
  value       = aws_instance.web_server.tags
}
```

### Step 3: Plan and Apply the Configuration
**Important:** Make sure you've updated terraform.tfvars with your username first!

```bash
# Set your username environment variable for this session
export TF_VAR_username="YOUR_USERNAME"  # Replace with your actual username

# Initialize Terraform with user-specific state file
terraform init -backend-config="path=terraform-${TF_VAR_username}.tfstate"

# Plan the changes
terraform plan

# Apply the changes
terraform apply
```

**Alternative using terraform.tfvars:**
```bash
# If you've set your username in terraform.tfvars file
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Step 4: Verify the Instance
```bash
# Show all outputs
terraform output

# Show specific output
terraform output instance_id

# Verify instance in AWS Console or CLI
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) --query 'Reservations[0].Instances[0].{State:State.Name,Type:InstanceType,Name:Tags[?Key==`Name`].Value|[0]}'
```

---

## Exercise 1.4: Explore Terraform State and Cleanup
**Duration:** 10 minutes

### Step 1: Examine Terraform State
```bash
# View current state in human-readable format
terraform show

# List all resources managed by Terraform
terraform state list

# Show details of a specific resource
terraform state show aws_instance.web_server
terraform state show random_pet.server_name
```

### Step 2: Understanding State
```bash
# View the raw state file (JSON format) - note the username prefix
ls -la terraform-*.tfstate
head -20 terraform-${TF_VAR_username}.tfstate
```

**Key observations about state:**
- Tracks resource metadata and current configuration
- Maps Terraform resources to real AWS resources
- Contains resource dependencies
- Should be protected and backed up in real environments

---

## Clean Up
**Duration:** 5 minutes

### Destroy Resources
```bash
# See what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing 'yes'
```

### Verify Cleanup
```bash
# Ensure no resources remain in state
terraform state list

# Verify in AWS (should show no instances)
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table
```

---

## Lab Summary and Key Takeaways

### What You've Learned
1. **Basic Terraform Workflow:**
   - `terraform init` - Initialize working directory
   - `terraform plan` - Preview changes
   - `terraform apply` - Apply changes
   - `terraform destroy` - Remove resources

2. **Terraform Configuration:**
   - Provider configuration
   - Resource definitions
   - Data sources
   - Variables and outputs

3. **State Management:**
   - State file tracks infrastructure
   - State enables change detection
   - State contains sensitive data

4. **Dependencies:**
   - Terraform automatically handles resource dependencies
   - Explicit dependencies with `depends_on`
   - Data sources provide external information

### Best Practices Introduced
- Use version constraints for providers
- Organize code with separate files
- Use variables for reusable configurations
- Tag resources for identification and management
- Always review plans before applying
- **Multi-user Environment:**
  - Use unique usernames for resource naming
  - Isolate state files per user
  - Validate input variables
  - Prefix all resource names with username

### Common Pitfalls to Avoid
- Don't edit state files manually
- Always use version control for configurations
- Be careful with destroy operations
- Don't commit sensitive data to version control

---

## Next Steps
In the next lab, you'll learn about:
- Advanced variable types and validation
- Locals and computed values
- Complex resource configurations
- Environment-specific deployments

---

## Additional Resources
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

---

## Troubleshooting Reference

### Common Commands for Debugging
```bash
# Validate syntax
terraform validate

# Format code
terraform fmt

# Show current state
terraform show

# List state resources
terraform state list

# Get help for any command
terraform plan -help
terraform apply -help
```

### Environment Variables for Debugging
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Log to file
export TF_LOG_PATH=terraform.log
terraform apply
```