# Lab 2: AWS Infrastructure with Terraform
**Duration:** 45 minutes
**Difficulty:** Introductory
**Day:** 1
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Configure the AWS provider and understand provider concepts
- Use data sources to query existing AWS infrastructure
- Create core AWS resources (S3, EC2, Security Groups)
- Define input variables with validation rules
- Create structured outputs for resource information

---

## 📋 **Prerequisites**
- Completion of Lab 1 (Introduction to Terraform)
- AWS Cloud9 environment with appropriate IAM permissions
- Terraform installed (from Lab 1)

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# Your username was saved by setup.sh in Lab 1 — confirm it is set
echo "Username: $TF_VAR_username"
```

> If it prints nothing, run `source ~/.bashrc`. If it shows the wrong name, re-run `bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <your-username>` and then `source ~/.bashrc`. Do **not** `export` a different value — every resource name includes it.

> **Note:** All lab resources deploy to **us-east-2** — the default of the `aws_region` variable — so there is no region to set. (Your Cloud9 IDE runs in us-east-1; that does not affect where Terraform deploys.)

### Navigate to the Lab Directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab02
```

---

## 📝 **Exercise 2.1: Review Configuration (15 minutes)**

The configuration files for this lab are already pre-created. In this exercise, you will review each file to understand how Terraform manages AWS infrastructure.

### Step 1: Review main.tf

Open `main.tf` and examine the configuration. This single file contains the Terraform block, provider configuration, data sources, and all resources.

```bash
cat main.tf
```

```hcl
# main.tf - AWS Infrastructure Deployment

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

# Data Sources - Query existing AWS infrastructure
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Generate random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for application storage
resource "aws_s3_bucket" "app_storage" {
  bucket        = "${var.username}-${var.environment}-storage-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "${var.username}-${var.environment}-storage"
    Environment = var.environment
    Owner       = var.username
    ManagedBy   = "Terraform"
    Lab         = "2"
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage_pab" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Security group for EC2 instance
resource "aws_security_group" "web_sg" {
  name        = "${var.username}-${var.environment}-web-sg"
  description = "Security group for web server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.username}-${var.environment}-web-sg"
    Environment = var.environment
    Owner       = var.username
    ManagedBy   = "Terraform"
    Lab         = "2"
  }
}

# EC2 instance
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Terraform Lab 2 - ${var.username}</h1>" > /var/www/html/index.html
    echo "<p>Environment: ${var.environment}</p>" >> /var/www/html/index.html
    echo "<p>Region: ${var.aws_region}</p>" >> /var/www/html/index.html
    echo "<p>Deployed with Terraform.</p>" >> /var/www/html/index.html
  EOF
  )

  tags = {
    Name        = "${var.username}-${var.environment}-web-server"
    Environment = var.environment
    Owner       = var.username
    ManagedBy   = "Terraform"
    Lab         = "2"
  }
}
```

#### Key Concepts in main.tf

**Terraform Block:** Defines version constraints for Terraform itself (`>= 1.9`) and the required providers (`aws ~> 5.0`, `random ~> 3.4`). This ensures everyone on the team uses compatible versions.

**Provider Configuration:** The `provider "aws"` block configures the AWS provider with a region from a variable. Providers are plugins that Terraform uses to interact with cloud APIs.

**Data Sources:** These read information from AWS without creating anything:
- `aws_caller_identity` -- Gets your AWS account ID
- `aws_region` -- Gets the current region name
- `aws_availability_zones` -- Lists available AZs in the region
- `aws_ami` -- Finds the latest Amazon Linux 2023 AMI using filters
- `aws_vpc` / `aws_subnets` -- Discovers the default VPC and its subnets

**Resources:** These create and manage actual infrastructure:
- `random_id` -- Generates a random hex suffix for globally unique S3 bucket names
- `aws_s3_bucket` -- Creates an S3 bucket with `force_destroy` enabled for easy cleanup
- `aws_s3_bucket_public_access_block` -- Blocks all public access to the bucket (security best practice)
- `aws_security_group` -- Creates a security group allowing HTTP (port 80) and SSH (port 22) inbound traffic
- `aws_instance` -- Launches a `t3.micro` EC2 instance with a user data script that installs and starts Apache HTTPD

---

### Step 2: Review variables.tf

Open `variables.tf` to see how input variables are defined with types, defaults, and validation rules.

```bash
cat variables.tf
```

```hcl
# variables.tf - Input variable definitions

variable "username" {
  description = "Your unique username (for shared environment)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters: lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}
```

#### Key Concepts in variables.tf

- **`username`** has no default value, so it must be provided. We set it via the `TF_VAR_username` environment variable. The validation block uses `can(regex(...))` to require 3-20 lowercase letters, numbers, or hyphens — the username becomes part of S3 bucket and security group names, so it must be safe for both.
- **`environment`** defaults to `"dev"` and uses the `contains()` function to only accept `"dev"`, `"staging"`, or `"prod"`.
- **`aws_region`** defaults to `"us-east-2"`, the class deployment region, so you never need to set it.
- **Validation blocks** run during `terraform plan` and `terraform apply`, catching invalid input before any resources are created.

---

### Step 3: Review outputs.tf

Open `outputs.tf` to see how Terraform exposes resource attributes after deployment.

```bash
cat outputs.tf
```

```hcl
# outputs.tf - Output value definitions

output "account_info" {
  description = "AWS account information"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    region     = data.aws_region.current.name
  }
}

output "s3_bucket" {
  description = "S3 bucket information"
  value = {
    name        = aws_s3_bucket.app_storage.bucket
    arn         = aws_s3_bucket.app_storage.arn
    domain_name = aws_s3_bucket.app_storage.bucket_domain_name
  }
}

output "ec2_instance" {
  description = "EC2 instance information"
  value = {
    id            = aws_instance.web_server.id
    public_ip     = aws_instance.web_server.public_ip
    instance_type = aws_instance.web_server.instance_type
  }
}

output "security_group" {
  description = "Security group information"
  value = {
    id   = aws_security_group.web_sg.id
    name = aws_security_group.web_sg.name
  }
}

output "web_application_url" {
  description = "URL to access the deployed web application"
  value       = "http://${aws_instance.web_server.public_ip}"
}
```

#### Key Concepts in outputs.tf

- Outputs use **structured maps** to group related information (e.g., `s3_bucket` returns name, ARN, and domain name together).
- The `web_application_url` output constructs a full URL from the EC2 instance's public IP, making it easy to access your deployed application.
- Data source outputs like `account_info` show information queried from AWS, not resources you created.
- Outputs are displayed after every `terraform apply` and can be queried individually with `terraform output <name>`.

---

## 🚀 **Exercise 2.2: Deploy and Validate (20 minutes)**

### Step 1: Initialize Terraform

```bash
terraform init
```

You should see Terraform downloading the AWS and Random providers. The output will show:
- Provider `hashicorp/aws` version `~> 5.0` installed
- Provider `hashicorp/random` version `~> 3.4` installed

### Step 2: Validate the Configuration

```bash
terraform validate
```

This checks the syntax and internal consistency of the configuration files. You should see: `Success! The configuration is valid.`

### Step 3: Preview the Deployment Plan

```bash
terraform plan
```

Review the plan output carefully. You should see Terraform planning to create:
- 1 `random_id` resource (bucket_suffix)
- 1 `aws_s3_bucket` resource (app_storage)
- 1 `aws_s3_bucket_public_access_block` resource (app_storage_pab)
- 1 `aws_security_group` resource (web_sg)
- 1 `aws_instance` resource (web_server)

The plan also reads data sources (caller identity, region, availability zones, AMI, VPC, subnets) to gather information needed by the resources.

### Step 4: Apply the Configuration

```bash
terraform apply
```

When prompted, type `yes` to confirm. Terraform will create all the resources. This may take 2-3 minutes, primarily waiting for the EC2 instance to launch.

### Step 5: Review the Outputs

```bash
# View all outputs
terraform output

# View specific outputs
terraform output account_info
terraform output s3_bucket
terraform output ec2_instance
terraform output web_application_url
```

### Step 6: Test the Web Application

```bash
# Get the web URL
WEB_URL=$(terraform output -raw web_application_url)
echo "Web URL: $WEB_URL"

# Test the web server (may take 1-2 minutes for user_data to complete)
curl $WEB_URL
```

You should see an HTML response containing your username, environment, and region. If the connection is refused, wait a minute or two for the EC2 user data script to finish installing and starting Apache.

### Step 7: Verify the S3 Bucket

```bash
# Get the bucket name
BUCKET_NAME=$(terraform output -json s3_bucket | jq -r '.name')
echo "Bucket name: $BUCKET_NAME"

# Verify the bucket exists
aws s3 ls s3://$BUCKET_NAME
```

### Step 8: Examine the State

```bash
# List all resources Terraform is managing
terraform state list

# Show details of a specific resource
terraform state show aws_instance.web_server
terraform state show aws_s3_bucket.app_storage
```

---

## 🔧 **Exercise 2.3: Explore and Modify (10 minutes)**

### Step 1: Change the Environment Variable

Let's see what happens when we change the `environment` variable from the default `"dev"` to `"staging"`.

```bash
terraform plan -var="environment=staging"
```

Review the plan output carefully. Notice how many resources Terraform wants to change. Resources that include the environment name in their configuration will be affected:
- The **S3 bucket** name includes the environment, and a bucket name cannot be changed, so it will be **destroyed and recreated** (`-/+` replacement)
- The **public access block** points at the bucket, so it is **replaced** along with it
- The **security group** name includes the environment, so it will be **destroyed and recreated** (`-/+` replacement)
- The **EC2 instance** user data, tags, and security group ID change, but none of these force a new instance, so it is **updated in-place** (`~`). AWS provider v5 stops the instance, swaps the user data, and starts it again — and the new script does **not** re-run, because cloud-init runs user data only on first boot.

You should see `Plan: 3 to add, 1 to change, 3 to destroy.` (The `random_id` suffix is unchanged.)

> **Tip:** If you want a user data change to rebuild the instance so the new script actually runs, set `user_data_replace_on_change = true` on the `aws_instance`. The instance would then show as a replacement (`-/+`) as well.

> **Important:** Do NOT apply this change. This exercise is to observe how variable changes cascade through your infrastructure. Simply review the plan output.

### Step 2: Test Variable Validation

Try providing an invalid environment value:

```bash
terraform plan -var="environment=invalid"
```

You should see the validation error: `Environment must be dev, staging, or prod.`

Try providing a username that is too short:

```bash
terraform plan -var="username=ab"
```

You should see: `Username must be 3-20 characters: lowercase letters, numbers, and hyphens.`

The same rule rejects uppercase letters and other characters:

```bash
terraform plan -var="username=User_1"
```

### Step 3: Inspect Resources in Detail

```bash
# View the full deployed state
terraform show

# Check the EC2 instance details
terraform state show aws_instance.web_server

# Check the security group rules
terraform state show aws_security_group.web_sg

# Check the S3 bucket configuration
terraform state show aws_s3_bucket.app_storage
```

---

## 📋 **Lab Summary**

In this lab, you accomplished the following:

- **Provider Configuration:** Configured the AWS provider with version constraints and a region variable
- **Data Sources:** Used six data sources to dynamically query AWS for account info, AMIs, VPCs, and subnets -- no hardcoded IDs
- **S3 Bucket:** Created a private S3 bucket with a globally unique name using `random_id` and blocked all public access
- **Security Group:** Defined a security group with HTTP and SSH ingress rules and unrestricted egress
- **EC2 Instance:** Launched a web server with an inline user data script that installs Apache HTTPD and serves a custom page
- **Variables with Validation:** Defined input variables with types, defaults, and validation rules that catch invalid input early
- **Structured Outputs:** Created map-based outputs to expose resource information after deployment

---

## 🧹 **Cleanup**

When you are finished with the lab, destroy all resources to avoid unnecessary AWS charges:

```bash
terraform destroy
```

When prompted, type `yes` to confirm. Terraform will remove all resources it created (EC2 instance, security group, S3 bucket, etc.).

Verify everything is cleaned up:

```bash
terraform state list
```

This should return no resources.

---

## ➡️ **Next Steps**

In **Lab 3**, you will learn:
- Advanced variable patterns with complex types (objects, maps, lists)
- Sensitive variable handling for secrets
- Enterprise tagging and cost allocation strategies
- Dynamic blocks and conditional resource creation
