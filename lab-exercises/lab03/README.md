# 🧪 Lab 3: Advanced Variables and Configuration

| | |
|---|---|
| **Duration** | 45 minutes |
| **Difficulty** | Intermediate |
| **Day** | 1 |
| **Environment** | AWS Cloud9 |

---

## 🎯 Learning Objectives

By the end of this lab, you will be able to:

- Define complex variable types (objects, maps, lists) with validation rules
- Implement variable validation for input constraints and business logic
- Use locals for computed values, naming patterns, and cost estimation
- Create dynamic blocks for flexible resource configuration
- Apply conditional expressions and enterprise tagging strategies

---

## 📋 Prerequisites

- Completion of **Lab 2** (Basic Infrastructure with Variables)
- Understanding of basic Terraform workflow (`init`, `plan`, `apply`)
- AWS Cloud9 environment with appropriate IAM permissions

---

## 🔧 Lab Setup

All configuration files for this lab have been pre-created. You will review each file to understand the concepts, then deploy the infrastructure.

```bash
# Navigate to the lab directory
cd ~/environment/lab03

# Set your username as an environment variable
export TF_VAR_username="<your-assigned-username>"

# Verify AWS access
aws sts get-caller-identity
```

> **Note:** Replace `<your-assigned-username>` with the username assigned to you by your instructor. You should also update the `username` value in `terraform.tfvars`.

---

## 📝 Exercise 3.1: Advanced Variable Definitions (15 minutes)

In this exercise, you will review the variable definitions and their assigned values to understand complex variable types and validation rules.

### Step 1: Review `variables.tf`

Open `variables.tf` and examine the variable definitions. Notice the different variable types and validation blocks.

**Basic validated variables** -- The `username` variable uses two validation blocks: one for length and one with a regex pattern:

```hcl
variable "username" {
  description = "Your unique username (for shared environment)"
  type        = string
  validation {
    condition     = length(var.username) > 2 && length(var.username) <= 20
    error_message = "Username must be between 3 and 20 characters."
  }
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.username))
    error_message = "Username must contain only lowercase letters, numbers, and hyphens."
  }
}
```

The `environment` variable uses `contains()` to restrict values to an allowed list:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

**Complex object variable** -- The `application_config` variable groups related settings into a single object with port validation:

```hcl
variable "application_config" {
  description = "Application configuration settings"
  type = object({
    name    = string
    version = string
    port    = number
  })
  validation {
    condition     = var.application_config.port >= 1024 && var.application_config.port <= 65535
    error_message = "Application port must be between 1024 and 65535."
  }
}
```

**Map of objects** -- The `instance_types` variable provides environment-specific instance configurations using a map of objects:

```hcl
variable "instance_types" {
  description = "Map of environment to instance configurations"
  type = map(object({
    instance_type = string
    volume_size   = number
    monitoring    = bool
  }))
  default = {
    dev = {
      instance_type = "t3.micro"
      volume_size   = 20
      monitoring    = false
    }
    staging = {
      instance_type = "t3.small"
      volume_size   = 30
      monitoring    = true
    }
    prod = {
      instance_type = "t3.medium"
      volume_size   = 50
      monitoring    = true
    }
  }
}
```

**Security configuration with CIDR validation** -- The `security_config` variable uses `alltrue()` with a `for` expression to validate every CIDR block:

```hcl
variable "security_config" {
  description = "Security settings for the infrastructure"
  type = object({
    enable_encryption   = bool
    enable_logging      = bool
    allowed_cidr_blocks = list(string)
    backup_enabled      = bool
  })
  validation {
    condition = alltrue([
      for cidr in var.security_config.allowed_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid CIDR notation."
  }
}
```

**Cost allocation with regex validation** -- The `cost_allocation` variable enforces a project code format like `TRF-2024`:

```hcl
variable "cost_allocation" {
  description = "Cost allocation and billing configuration"
  type = object({
    project_code = string
    cost_center  = string
    billing_team = string
  })
  validation {
    condition     = can(regex("^[A-Z]{3}-[0-9]{4}$", var.cost_allocation.project_code))
    error_message = "Project code must follow format: ABC-1234."
  }
}
```

**Enterprise tagging** -- The `tags` variable provides a simple map for common resource tags with an empty default:

```hcl
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### Step 2: Review `terraform.tfvars`

Open `terraform.tfvars` to see how values are assigned to these complex variables:

```hcl
# Basic configuration
username    = "user1" # Replace with your assigned username
environment = "dev"

# Application configuration
application_config = {
  name    = "web-app"
  version = "1.0.0"
  port    = 8080
}

# Security configuration
security_config = {
  enable_encryption   = true
  enable_logging      = true
  allowed_cidr_blocks = ["10.0.0.0/16", "172.16.0.0/12"]
  backup_enabled      = true
}

# Enterprise tagging
tags = {
  Owner       = "DevOps Team"
  Project     = "Terraform Training"
  Environment = "Development"
  CostCenter  = "Engineering"
}

# Cost allocation
cost_allocation = {
  project_code = "TRF-2024"
  cost_center  = "Engineering"
  billing_team = "Platform Team"
}
```

> **Key Concept:** Notice how each complex variable value matches the structure defined by its `type` constraint in `variables.tf`. Terraform will return a clear error if any field is missing or has the wrong type.

---

## 📝 Exercise 3.2: Data Sources and Locals (10 minutes)

In this exercise, you will review how data sources discover existing AWS resources and how locals compute derived values.

### Step 1: Review `data.tf`

Open `data.tf` and examine the data sources. These query AWS for existing resources rather than creating new ones.

**AMI lookup** -- Finds the latest Amazon Linux 2 AMI dynamically:

```hcl
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

  filter {
    name   = "state"
    values = ["available"]
  }
}
```

**Account and region discovery** -- These data sources retrieve runtime context:

```hcl
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
```

**Default VPC and subnets** -- Discovers the default VPC and its subnets for deploying resources:

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

### Step 2: Review `locals.tf`

Open `locals.tf` to see how computed values are derived from variables and data sources.

```hcl
locals {
  # Environment-specific configuration
  current_config = var.instance_types[var.environment]

  # Common naming prefix
  name_prefix = "${var.username}-${var.environment}"

  # Enhanced tagging strategy
  common_tags = merge(var.tags, {
    Environment = var.environment
    Owner       = var.username
    Application = var.application_config.name
    Version     = var.application_config.version
    ManagedBy   = "Terraform"
    ProjectCode = var.cost_allocation.project_code
    CostCenter  = var.cost_allocation.cost_center
    Region      = data.aws_region.current.name
  })

  # Security group rules configuration
  ingress_rules = {
    http = {
      port        = 80
      protocol    = "tcp"
      description = "HTTP access"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    https = {
      port        = 443
      protocol    = "tcp"
      description = "HTTPS access"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    app = {
      port        = var.application_config.port
      protocol    = "tcp"
      description = "Application port"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    ssh = {
      port        = 22
      protocol    = "tcp"
      description = "SSH access (restricted)"
      cidr_blocks = ["10.0.0.0/8"]
    }
  }

  # Cost estimation
  estimated_monthly_cost = {
    instance = local.current_config.instance_type == "t3.micro" ? 8.5 : local.current_config.instance_type == "t3.small" ? 17 : 34
    storage  = local.current_config.volume_size * 0.10
  }

  # Resource naming patterns
  resource_names = {
    web_sg     = "${local.name_prefix}-web-sg"
    s3_bucket  = "${local.name_prefix}-logs"
    ec2_instance = "${local.name_prefix}-web"
  }
}
```

> **Key Concepts:**
> - `var.instance_types[var.environment]` performs a map lookup -- changing `environment` automatically selects different instance sizes.
> - `merge()` combines multiple maps, with later values overriding earlier ones.
> - The `ingress_rules` map will drive a `dynamic` block in `main.tf`.
> - Ternary expressions (`condition ? true_val : false_val`) estimate costs by instance type.

---

## 📝 Exercise 3.3: Dynamic Infrastructure (10 minutes)

In this exercise, you will review `main.tf` to understand dynamic blocks, conditional expressions, and how locals drive resource configuration.

### Step 1: Review the Security Group with Dynamic Block

The security group uses a `dynamic` block to generate ingress rules from the `local.ingress_rules` map:

```hcl
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web servers"
  vpc_id      = data.aws_vpc.default.id

  # Dynamic ingress rules from local configuration
  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
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

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
    Type = "WebServer"
  })
}
```

> **Key Concept:** The `dynamic` block iterates over `local.ingress_rules` and generates one `ingress` block per map entry. Adding or removing entries from the map automatically adjusts the security group rules -- no code duplication needed.

### Step 2: Review the EC2 Instance

The EC2 instance demonstrates several patterns -- map lookup via locals, conditional key pair, and conditional encryption:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.current_config.instance_type
  subnet_id     = data.aws_subnets.default.ids[0]
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  vpc_security_group_ids = [aws_security_group.web.id]

  monitoring = local.current_config.monitoring

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = local.current_config.volume_size
    volume_type           = "gp3"
    encrypted             = var.security_config.enable_encryption
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>${var.application_config.name} v${var.application_config.version}</h1>" > /var/www/html/index.html
    echo "<p>Environment: ${var.environment}</p>" >> /var/www/html/index.html
    echo "<p>Owner: ${var.username}</p>" >> /var/www/html/index.html
    echo '{"status":"healthy"}' > /var/www/html/health
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
    Type = "WebServer"
  })
}
```

> **Key Concepts:**
> - `local.current_config.instance_type` selects the instance type based on environment.
> - `var.key_pair_name != "" ? var.key_pair_name : null` conditionally sets the key pair -- passing `null` omits the argument entirely.
> - `var.security_config.enable_encryption` toggles EBS encryption based on configuration.
> - The `user_data` script installs Apache and creates a page showing the application name and environment.
>
> The `key_pair_name` variable (defined in `variables.tf` with an empty default) allows optional SSH access.

### Step 4: Review `versions.tf`

Note how the provider uses `default_tags` to automatically apply tags to all resources:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = var.username
      ManagedBy   = "Terraform"
      Project     = var.application_config.name
    }
  }
}
```

---

## 📝 Exercise 3.4: Deploy and Validate (10 minutes)

Now that you understand all the configuration files, deploy the infrastructure and examine the outputs.

### Step 1: Initialize Terraform

```bash
terraform init
```

### Step 2: Validate and Plan

```bash
# Validate the configuration syntax
terraform validate

# Generate and review the execution plan
terraform plan
```

Review the plan output carefully. You should see the following resources:

- `aws_security_group.web` (with 4 dynamic ingress rules)
- `aws_instance.web`

### Step 3: Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### Step 4: Review Outputs

```bash
# View all outputs
terraform output

# View specific outputs
terraform output environment_info
terraform output configuration_summary
terraform output cost_estimation
terraform output resource_names
terraform output application_url
```

### Step 5: Verify Resources in AWS

```bash
# Check the EC2 instance
terraform output ec2_instance

# Check the security group
terraform output security_group

# View the tagging strategy
terraform output tagging_strategy
```

### Step 6: Experiment with Variable Changes (Optional)

Try changing the environment to see how it affects the plan:

```bash
# Plan with a different environment
terraform plan -var="environment=staging"
```

Notice how the instance type, volume size, and monitoring settings all change based on the environment map lookup.

---

## 📋 Lab Summary

In this lab, you explored advanced Terraform variable and configuration patterns:

| Concept | Where Used | Purpose |
|---|---|---|
| **Object variables** | `application_config`, `security_config`, `cost_allocation` | Group related settings into structured types |
| **Map of objects** | `instance_types` | Environment-specific configurations via map lookup |
| **Variable validation** | `username`, `environment`, `application_config`, `security_config`, `cost_allocation` | Enforce input constraints before deployment |
| **Data sources** | `data.tf` | Dynamically discover AMIs, VPCs, subnets, and account info |
| **Locals** | `locals.tf` | Compute naming prefixes, merge tags, define ingress rules, estimate costs |
| **Dynamic blocks** | Security group ingress rules | Generate repeated blocks from a map without duplication |
| **Conditional expressions** | Key pair (`null`), encryption toggle | Toggle arguments based on configuration |
| **Enterprise tagging** | `common_tags`, `default_tags` | Consistent tagging for cost allocation and compliance |

---

## 🧹 Cleanup

When you are finished with the lab, destroy all resources to avoid ongoing charges:

```bash
terraform destroy
```

Type `yes` when prompted to confirm destruction.

---

## ➡️ Next Steps

In **Lab 4**, you will learn about:

- Resource dependencies and lifecycle management
- Advanced `count` and `for_each` patterns
- Complex resource relationships
- State management strategies
