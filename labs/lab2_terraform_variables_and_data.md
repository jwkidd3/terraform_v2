# Lab 2: Terraform Variables and Data Sources
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
- `user1-webapp-dev-web-xxxxx` (instance name)
- `user1-webapp-dev-web-` prefixed security group
- `terraform-user1.tfstate` state file

---

## Lab Objectives
By the end of this lab, you will be able to:
- Work with input variables and validation
- Use locals for computed values
- Implement data sources to reference existing AWS resources
- Understand variable precedence and different input methods

---

## Prerequisites
- Completion of Lab 1
- AWS Cloud9 environment set up
- Basic understanding of Terraform workflow

---

## Exercise 2.1: Input Variables and Validation
**Duration:** 15 minutes

### Step 1: Create Lab Directory
```bash
# Navigate to home directory and create new lab
cd ~
mkdir terraform-lab2
cd terraform-lab2

# Set your username environment variable (replace YOUR_USERNAME with your actual username)
export TF_VAR_username="YOUR_USERNAME"

# Create file structure
touch main.tf variables.tf outputs.tf terraform.tfvars
```

### Step 2: Define Variables with Validation
Create `variables.tf`:

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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be from t2 or t3 family."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-lab"
}

variable "allowed_cidrs" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["10.0.0.0/8"]
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidrs :
      can(cidrnetmask(cidr))
    ])
    error_message = "All values must be valid CIDR blocks."
  }
}

variable "enable_monitoring" {
  description = "Whether to enable detailed monitoring"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Owner     = "Student"
  }
}
```

### Step 3: Test Variable Validation
Create a basic `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Note: Backend will be configured during terraform init
  # State file will be isolated per user
}

provider "aws" {
  region = "us-east-2"
}

# This resource just validates our variables
resource "null_resource" "validation_test" {
  triggers = {
    username         = var.username
    environment      = var.environment
    instance_type    = var.instance_type  
    project_name     = var.project_name
    enable_monitoring = var.enable_monitoring
  }
}
```

Test validation:
```bash
# Initialize with user-specific state file
terraform init -backend-config="path=terraform-${TF_VAR_username}.tfstate"

# Test with valid values (should include username)
terraform plan

# Test with invalid environment - this should fail
terraform plan -var="environment=invalid"

# Test with invalid instance type - this should fail  
terraform plan -var="instance_type=m5.large"

# Test with invalid username - this should fail
terraform plan -var="username=123invalid"
```

---

## Exercise 2.2: Working with Locals
**Duration:** 15 minutes

### Step 1: Add Locals to main.tf
Update your `main.tf` to include locals:

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

# Generate a random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # Computed values with username prefix
  resource_prefix = "${var.username}-${var.project_name}-${var.environment}"
  
  # Conditional values
  instance_name = "${local.resource_prefix}-web-${random_id.suffix.hex}"
  
  # Environment-specific configuration
  instance_config = var.environment == "prod" ? {
    instance_type = "t3.small"
    monitoring    = true
  } : {
    instance_type = var.instance_type
    monitoring    = var.enable_monitoring
  }
  
  # Merged tags
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Name        = local.instance_name
  })
  
  # Complex computations
  security_group_rules = [
    for cidr in var.allowed_cidrs : {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [cidr]
      description = "SSH access from ${cidr}"
    }
  ]
}

# Create security group using locals with username prefix
resource "aws_security_group" "web" {
  name_prefix = "${local.resource_prefix}-web-"
  description = "Security group for ${local.instance_name} (user: ${var.username})"
  
  dynamic "ingress" {
    for_each = local.security_group_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = local.common_tags
}

# Create EC2 instance using locals
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.instance_config.instance_type
  
  vpc_security_group_ids = [aws_security_group.web.id]
  monitoring             = local.instance_config.monitoring
  
  tags = local.common_tags
}
```

### Step 2: Create Variable Values File
Update `terraform.tfvars` (replace "user1" with your unique username):

```hcl
# IMPORTANT: Replace "user1" with your unique username
username         = "user1"
environment      = "dev"
project_name     = "webapp"
instance_type    = "t2.micro"
enable_monitoring = false
allowed_cidrs    = ["10.0.0.0/8", "172.16.0.0/12"]

tags = {
  Owner      = "DevTeam"
  CostCenter = "Engineering"
  ManagedBy  = "Terraform"
}
```

### Step 3: Test the Configuration
```bash
# Plan and apply (ensure your username is set)
terraform plan
terraform apply

# Observe how locals are computed and used
# Notice how all resource names include your username prefix
```

---

## Exercise 2.3: Data Sources
**Duration:** 15 minutes

### Step 1: Add Data Sources
Add data sources to your `main.tf`:

```hcl
# Add after the provider block

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get the latest Amazon Linux 2 AMI
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

# Get caller identity (current AWS account info)
data "aws_caller_identity" "current" {}

# Get current region
data "aws_region" "current" {}
```

### Step 2: Use Data Sources in Resources
Update the locals and EC2 instance:

```hcl
locals {
  # Previous locals remain the same...
  # Add new computed values
  
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Update common tags to include account/region info and username
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Name        = local.instance_name
    Account     = local.account_id
    Region      = local.region
    Username    = var.username
  })
}

# Update the security group to use default VPC
resource "aws_security_group" "web" {
  name_prefix = "${local.resource_prefix}-web-"
  description = "Security group for ${local.instance_name}"
  vpc_id      = data.aws_vpc.default.id  # Use data source
  
  # Rest remains the same...
}

# Update the EC2 instance to use AMI data source
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id  # Use data source
  instance_type = local.instance_config.instance_type
  
  vpc_security_group_ids = [aws_security_group.web.id]
  monitoring             = local.instance_config.monitoring
  
  # Use first available AZ
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = local.common_tags
}
```

### Step 3: Add Data Source Outputs
Update `outputs.tf`:

```hcl
output "instance_details" {
  description = "EC2 instance information"
  value = {
    id                = aws_instance.web.id
    public_ip         = aws_instance.web.public_ip
    private_ip        = aws_instance.web.private_ip
    availability_zone = aws_instance.web.availability_zone
    instance_type     = aws_instance.web.instance_type
    username         = var.username
  }
}

output "security_group_details" {
  description = "Security group information"
  value = {
    id   = aws_security_group.web.id
    name = aws_security_group.web.name
  }
}

output "environment_info" {
  description = "Environment and account information"
  value = {
    username          = var.username
    account_id        = data.aws_caller_identity.current.account_id
    region           = data.aws_region.current.name
    vpc_id           = data.aws_vpc.default.id
    ami_id           = data.aws_ami.amazon_linux.id
    ami_name         = data.aws_ami.amazon_linux.name
    availability_zones = data.aws_availability_zones.available.names
  }
}
```

### Step 4: Apply and Explore
```bash
# Apply the updated configuration
terraform apply

# View outputs
terraform output

# View specific output
terraform output environment_info

# View in JSON format
terraform output -json environment_info
```

---

## Exercise 2.4: Variable Input Methods
**Duration:** 10 minutes

### Step 1: Test Different Variable Input Methods
Test various ways to provide variables:

```bash
# Method 1: Command line variables (remember to include username)
terraform plan -var="username=${TF_VAR_username}" -var="environment=staging" -var="instance_type=t3.micro"

# Method 2: Environment variables (username should already be set)
export TF_VAR_environment="prod"
export TF_VAR_enable_monitoring="true"
# TF_VAR_username should already be set from earlier
terraform plan

# Method 3: Variable files
echo "username = \"${TF_VAR_username}\"" > staging.tfvars
echo 'environment = "staging"' >> staging.tfvars
echo 'instance_type = "t3.small"' >> staging.tfvars
echo 'enable_monitoring = true' >> staging.tfvars

terraform plan -var-file="staging.tfvars"

# Method 4: Auto-loaded files
echo "username = \"${TF_VAR_username}\"" > terraform.auto.tfvars
echo 'project_name = "auto-loaded-project"' >> terraform.auto.tfvars
terraform plan

# Clean up environment variables
unset TF_VAR_environment
unset TF_VAR_enable_monitoring
```

### Step 2: Variable Precedence Test
Create multiple variable files:

```bash
# Create variables with different values
echo "username = \"${TF_VAR_username}\"" > terraform.tfvars
echo 'environment = "from-tfvars"' >> terraform.tfvars
echo "username = \"${TF_VAR_username}\"" > auto.auto.tfvars
echo 'environment = "from-auto"' >> auto.auto.tfvars
echo "username = \"${TF_VAR_username}\"" > test.tfvars
echo 'environment = "from-file"' >> test.tfvars

# Test precedence (command line should win)
terraform plan -var="username=${TF_VAR_username}" -var="environment=from-command-line" -var-file="test.tfvars"
```

---

## Lab Summary and Key Takeaways

### What You've Learned
1. **Variable Validation:**
   - Input validation with custom rules
   - Type constraints and error messages
   - Complex validation conditions

2. **Locals:**
   - Computed values and expressions
   - Conditional logic in locals
   - Complex data transformations

3. **Data Sources:**
   - Querying existing AWS resources
   - Using data sources in configurations
   - Combining data sources with variables

4. **Variable Input Methods:**
   - Command line variables
   - Environment variables
   - Variable files (.tfvars)
   - Auto-loaded variable files

5. **Multi-User Considerations:**
   - Username-based resource naming
   - State file isolation
   - Variable validation for usernames
   - Resource tagging with user information

### Clean Up
```bash
# Destroy resources (your username-prefixed resources)
terraform destroy

# Remove temporary files
rm *.tfvars

# Verify your state file is cleaned up
ls -la terraform-*.tfstate*
```

---

## Next Steps
In Lab 3, you'll learn about:
- Resource dependencies and lifecycle management
- Working with multiple resources
- Output dependencies and references
- Advanced resource configuration patterns

---

## Troubleshooting

### Common Issues
1. **Variable validation failures:** Check regex patterns and condition logic
2. **Data source not found:** Ensure the resource exists in your AWS account
3. **Variable precedence confusion:** Remember command line > var-file > env vars > defaults
4. **AMI not found:** AMI IDs are region-specific; use data sources for portability