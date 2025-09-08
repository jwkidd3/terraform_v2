# Lab 7: Advanced Patterns and CI/CD Integration
**Duration:** 45 minutes  
**Difficulty:** Advanced  
**Day:** 2  
**Environment:** AWS Cloud9 + GitHub Actions

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. All resources will be prefixed with your username
4. CI/CD pipelines and repositories will be user-specific
5. This ensures isolated development environments

**Example:** If your username is "user1", your resources will be named:
- `user1-cicd-demo-codecommit-repo`
- `user1-terraform-cicd-pipeline`
- State key: `user1/cicd/terraform.tfstate`

---

## Lab Objectives
By the end of this lab, you will be able to:
- Implement advanced Terraform patterns and best practices
- Set up automated CI/CD pipelines with GitHub Actions
- Configure automated testing and validation
- Implement deployment strategies for production environments
- Use policy as code for governance

---

## Prerequisites
- Completion of Labs 1-6
- GitHub account with repository access
- AWS Cloud9 environment set up
- Understanding of Git workflows

---

## Exercise 7.1: Advanced Terraform Patterns
**Duration:** 15 minutes

### Step 1: Create Advanced Lab Environment
```bash
mkdir terraform-lab7
cd terraform-lab7

# Create directory structure
mkdir -p {environments/{dev,staging,prod},modules/{networking,security,compute},policies}

touch main.tf variables.tf outputs.tf versions.tf
```

### Step 2: Implement Environment-Specific Configuration
**environments/dev/terraform.tfvars:**
```hcl
# Development environment configuration
project_name      = "advanced-terraform-lab"
environment       = "dev"
aws_region        = "us-east-2"

# Infrastructure sizing
instance_type     = "t2.micro"
min_size         = 1
max_size         = 2
desired_capacity = 1

# Feature flags
enable_monitoring     = false
enable_backup        = false
enable_logging       = true
enable_multi_az      = false

# Network configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-2a", "us-east-2b"]

# Security configuration
allowed_cidr_blocks = ["10.0.0.0/8"]

# Tags
common_tags = {
  Environment    = "dev"
  Project       = "advanced-terraform-lab"
  Owner         = "DevTeam"
  CostCenter    = "Engineering"
  ManagedBy     = "Terraform"
  BackupSchedule = "none"
}
```

**environments/prod/terraform.tfvars:**
```hcl
# Production environment configuration
project_name      = "advanced-terraform-lab"
environment       = "prod"
aws_region        = "us-east-2"

# Infrastructure sizing
instance_type     = "t3.small"
min_size         = 2
max_size         = 10
desired_capacity = 3

# Feature flags
enable_monitoring     = true
enable_backup        = true
enable_logging       = true
enable_multi_az      = true

# Network configuration
vpc_cidr = "10.1.0.0/16"
availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]

# Security configuration
allowed_cidr_blocks = ["10.1.0.0/16"]

# Tags
common_tags = {
  Environment    = "prod"
  Project       = "advanced-terraform-lab"
  Owner         = "OpsTeam"
  CostCenter    = "Production"
  ManagedBy     = "Terraform"
  BackupSchedule = "daily"
  Compliance    = "required"
}
```

### Step 3: Create Advanced Variables Configuration
**variables.tf:**
```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones must be specified."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  
  validation {
    condition     = can(regex("^[tm][2-9]\\.", var.instance_type))
    error_message = "Instance type must be from t2, t3, t4, m4, m5, m6 family."
  }
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  
  validation {
    condition     = var.min_size >= 1 && var.min_size <= 10
    error_message = "Min size must be between 1 and 10."
  }
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  
  validation {
    condition     = var.max_size >= 1 && var.max_size <= 20
    error_message = "Max size must be between 1 and 20."
  }
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "enable_backup" {
  description = "Enable backup policies"
  type        = bool
  default     = false
}

variable "enable_logging" {
  description = "Enable logging"
  type        = bool
  default     = true
}

variable "enable_multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for access"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
```

### Step 4: Implement Advanced Resource Patterns
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
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Advanced locals with complex logic
locals {
  # Environment-specific configurations
  environment_config = {
    dev = {
      backup_retention = 7
      log_retention   = 30
    }
    staging = {
      backup_retention = 14
      log_retention   = 90
    }
    prod = {
      backup_retention = 30
      log_retention   = 365
    }
  }
  
  current_env_config = local.environment_config[var.environment]
  
  # Subnet calculations
  private_subnet_cidrs = [
    for i in range(length(var.availability_zones)) :
    cidrsubnet(var.vpc_cidr, 8, i + 10)
  ]
  
  public_subnet_cidrs = [
    for i in range(length(var.availability_zones)) :
    cidrsubnet(var.vpc_cidr, 8, i + 100)
  ]
  
  # Resource naming
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Conditional resource counts
  nat_gateway_count = var.enable_multi_az ? length(var.availability_zones) : 1
}

# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.availability_zones)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "private"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = local.nat_gateway_count
  
  domain = "vpc"
  
  depends_on = [aws_internet_gateway.main]
  
  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb-${random_id.suffix.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  enable_deletion_protection = var.environment == "prod" ? true : false
  
  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-web-"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}
```

---

## Exercise 7.2: CI/CD Pipeline Setup
**Duration:** 20 minutes

### Step 1: Create GitHub Repository Structure
```bash
# Initialize git repository
git init

# Create GitHub Actions workflow directory
mkdir -p .github/workflows

# Create additional directories
mkdir -p {scripts,tests,docs}
```

### Step 2: Create GitHub Actions Workflow
**.github/workflows/terraform.yml:**
```yaml
name: 'Terraform CI/CD Pipeline'

on:
  push:
    branches: [ "main", "develop" ]
    paths:
      - '**.tf'
      - '**.tfvars'
      - '.github/workflows/terraform.yml'
  pull_request:
    branches: [ "main" ]
    paths:
      - '**.tf'
      - '**.tfvars'

env:
  TF_VERSION: '1.6.6'
  AWS_REGION: 'us-east-2'

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  validate:
    name: 'Terraform Validate'
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Format Check
      id: fmt
      run: terraform fmt -check -recursive
      continue-on-error: true

    - name: Terraform Init
      id: init
      run: terraform init -backend=false

    - name: Terraform Validate
      id: validate
      run: terraform validate -no-color

    - name: Update Pull Request
      uses: actions/github-script@v7
      if: github.event_name == 'pull_request'
      env:
        FORMAT: ${{ steps.fmt.outcome }}
        INIT: ${{ steps.init.outcome }}
        VALIDATE: ${{ steps.validate.outcome }}
      with:
        script: |
          const output = `#### Terraform Format and Style 🖌\`${{ steps.fmt.outcome }}\`
          #### Terraform Initialization ⚙️\`${{ steps.init.outcome }}\`
          #### Terraform Validation 🤖\`${{ steps.validate.outcome }}\`
          
          *Pusher: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: output
          })

  security:
    name: 'Security Scan'
    runs-on: ubuntu-latest
    needs: validate
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Run tfsec
      uses: aquasecurity/tfsec-action@v1.0.3
      with:
        additional_args: --format json --out tfsec-results.json
        
    - name: Upload tfsec results
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: tfsec-results
        path: tfsec-results.json

  plan-dev:
    name: 'Terraform Plan - Dev'
    runs-on: ubuntu-latest
    needs: [validate, security]
    if: github.event_name == 'pull_request'
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Init
      run: terraform init

    - name: Terraform Plan
      id: plan
      run: |
        terraform plan -var-file="environments/dev/terraform.tfvars" \
                      -no-color -input=false -out=tfplan
      continue-on-error: true

    - name: Comment Plan
      uses: actions/github-script@v7
      if: github.event_name == 'pull_request'
      env:
        PLAN: ${{ steps.plan.outputs.stdout }}
      with:
        script: |
          const output = `#### Terraform Plan - Development Environment 📖\`${{ steps.plan.outcome }}\`
          
          <details><summary>Show Plan</summary>
          
          \`\`\`terraform\n
          ${process.env.PLAN}
          \`\`\`
          
          </details>
          
          *Pusher: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: output
          })

  deploy-dev:
    name: 'Deploy to Development'
    runs-on: ubuntu-latest
    needs: [validate, security]
    if: github.ref == 'refs/heads/develop'
    environment: development
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Init
      run: terraform init

    - name: Terraform Apply
      run: |
        terraform apply -var-file="environments/dev/terraform.tfvars" \
                       -auto-approve -input=false

    - name: Save Terraform Outputs
      run: terraform output -json > terraform-outputs.json

    - name: Upload outputs
      uses: actions/upload-artifact@v4
      with:
        name: terraform-outputs-dev
        path: terraform-outputs.json

  deploy-prod:
    name: 'Deploy to Production'
    runs-on: ubuntu-latest
    needs: [validate, security]
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Init
      run: terraform init

    - name: Terraform Plan
      run: |
        terraform plan -var-file="environments/prod/terraform.tfvars" \
                      -input=false -out=tfplan

    - name: Terraform Apply
      run: terraform apply tfplan
```

### Step 3: Create Policy as Code Configuration
**policies/security-policy.rego:**
```rego
package terraform.security

import future.keywords.in

# Deny resources without required tags
required_tags := ["Environment", "Project", "Owner", "ManagedBy"]

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type in ["aws_instance", "aws_s3_bucket", "aws_vpc"]
    
    missing_tags := [tag | 
        tag := required_tags[_]
        not resource.values.tags[tag]
    ]
    
    count(missing_tags) > 0
    msg := sprintf("Resource %s missing required tags: %v", 
        [resource.address, missing_tags])
}

# Deny overly permissive security groups
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group"
    
    rule := resource.values.ingress[_]
    rule.cidr_blocks[_] == "0.0.0.0/0"
    rule.from_port <= 22
    rule.to_port >= 22
    
    msg := sprintf("Security group %s allows SSH access from 0.0.0.0/0", 
        [resource.address])
}

# Warn about expensive instance types
expensive_instances := ["m5.large", "m5.xlarge", "c5.large", "c5.xlarge"]

warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_instance"
    
    resource.values.instance_type in expensive_instances
    
    msg := sprintf("Instance %s uses expensive instance type: %s", 
        [resource.address, resource.values.instance_type])
}
```

### Step 4: Create Testing Scripts
**scripts/validate.sh:**
```bash
#!/bin/bash
set -e

echo "Running Terraform validation tests..."

# Format check
echo "Checking Terraform formatting..."
terraform fmt -check -recursive

# Validation check
echo "Validating Terraform configuration..."
terraform init -backend=false
terraform validate

# Security scan
echo "Running security scan..."
if command -v tfsec &> /dev/null; then
    tfsec .
else
    echo "tfsec not installed, skipping security scan"
fi

# Policy check (if conftest is available)
if command -v conftest &> /dev/null; then
    echo "Running policy checks..."
    terraform plan -var-file="environments/dev/terraform.tfvars" -out=tfplan
    terraform show -json tfplan > plan.json
    conftest verify --policy policies/ plan.json
else
    echo "conftest not installed, skipping policy checks"
fi

echo "All validation tests passed!"
```

**Make script executable:**
```bash
chmod +x scripts/validate.sh
```

---

## Exercise 7.3: Testing and Validation
**Duration:** 10 minutes

### Step 1: Local Testing Setup
**Create test configuration:**
```bash
# Create simple test
./scripts/validate.sh
```

### Step 2: Create GitHub Repository and Push Code
```bash
# Add all files
git add .

# Create initial commit
git commit -m "Initial advanced Terraform configuration with CI/CD"

# Create GitHub repository (via GitHub CLI or web interface)
# Replace with your actual repository URL
git remote add origin https://github.com/YOUR_USERNAME/terraform-lab7.git
git branch -M main
git push -u origin main
```

### Step 3: Configure GitHub Secrets
In your GitHub repository:
1. Go to Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key

### Step 4: Test CI/CD Pipeline
```bash
# Create a feature branch
git checkout -b feature/update-instance-type

# Make a change to trigger the pipeline
# Edit environments/dev/terraform.tfvars
sed -i 's/t2.micro/t2.small/' environments/dev/terraform.tfvars

# Commit and push
git add .
git commit -m "Update dev instance type to t2.small"
git push origin feature/update-instance-type
```

1. Create a Pull Request on GitHub
2. Observe the automated checks running
3. Review the Terraform plan in the PR comments
4. Merge the PR to trigger deployment

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Advanced Terraform Patterns:**
   - Environment-specific configurations
   - Complex variable validation and locals
   - Conditional resource creation
   - Advanced resource patterns

2. **CI/CD Integration:**
   - GitHub Actions workflows for Terraform
   - Automated validation and security scanning
   - Environment-specific deployments
   - Pull request automation

3. **Policy as Code:**
   - Security policy enforcement with OPA
   - Cost control policies
   - Compliance automation
   - Governance frameworks

4. **Production Patterns:**
   - Multi-environment management
   - Automated testing strategies
   - Deployment approvals and gates
   - Infrastructure monitoring

### Best Practices Implemented

- **Separation of Concerns:** Environment-specific configurations
- **Automation:** Complete CI/CD pipeline with testing
- **Security:** Automated security scanning and policy checks
- **Governance:** Policy as code and approval workflows
- **Maintainability:** Clear code structure and documentation

### Production Considerations

1. **Security:**
   - Use OIDC instead of long-term credentials
   - Implement least privilege access
   - Regular security scanning and updates

2. **State Management:**
   - Remote state with locking
   - State backup and recovery procedures
   - Environment isolation

3. **Monitoring:**
   - Infrastructure monitoring and alerting
   - Cost monitoring and optimization
   - Compliance tracking

### Clean Up
```bash
# Destroy dev environment
terraform destroy -var-file="environments/dev/terraform.tfvars" -auto-approve

# Or trigger destruction via GitHub Actions
```

---

## Next Steps
You've now completed advanced Terraform training! Consider:
- HashiCorp Terraform Associate certification
- Implementing these patterns in your organization
- Exploring Terraform Enterprise features
- Contributing to open-source Terraform modules

---

## Troubleshooting

### Common CI/CD Issues

1. **GitHub Actions Authentication:**
   - Verify AWS credentials are properly set as secrets
   - Check IAM permissions for the AWS user

2. **Terraform State Conflicts:**
   - Ensure proper backend configuration
   - Use state locking to prevent conflicts

3. **Policy Failures:**
   - Review policy rules and fix violations
   - Update policies as needed for your environment

4. **Pipeline Timeouts:**
   - Optimize Terraform configurations for faster execution
   - Adjust GitHub Actions timeout settings

### Additional Resources
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [tfsec Security Scanner](https://aquasecurity.github.io/tfsec/)
- [Open Policy Agent](https://www.openpolicyagent.org/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)