# Lab 12: GitHub-Triggered Terraform Cloud Deployments
**Duration:** 45 minutes  
**Difficulty:** Advanced  
**Day:** 3  
**Environment:** GitHub + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Connect a GitHub repository to Terraform Cloud workspaces
- Implement VCS-driven workflows for infrastructure deployment
- Configure automatic plan and apply triggers based on Git events
- Set up branch protection and approval workflows
- Implement GitOps patterns for infrastructure management
- Create a CI/CD pipeline for infrastructure changes

---

## 📋 **Prerequisites**
- Completion of Labs 9-11 (Terraform Cloud fundamentals)
- GitHub account with repository creation permissions
- Terraform Cloud account (free tier is sufficient)
- Basic Git knowledge

---

## 🛠️ **Lab Setup**

### Required Accounts
```bash
# Verify you have:
# 1. GitHub account - https://github.com
# 2. Terraform Cloud account - https://app.terraform.io
# 3. AWS credentials configured in Terraform Cloud (from Lab 9)

# Set your username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 12.1: Create GitHub Repository (10 minutes)**

### Step 1: Create a New GitHub Repository
1. Go to https://github.com/new
2. Repository name: `terraform-cloud-infrastructure`
3. Description: "Infrastructure as Code with Terraform Cloud"
4. Set to **Public** (or Private if you prefer)
5. Initialize with README: **Yes**
6. Add .gitignore: Select **Terraform**
7. Click **Create repository**

### Step 2: Clone the Repository Locally
```bash
# Clone your repository (replace YOUR_GITHUB_USERNAME)
git clone https://github.com/YOUR_GITHUB_USERNAME/terraform-cloud-infrastructure.git
cd terraform-cloud-infrastructure

# Create initial branch structure
git checkout -b development
git checkout -b staging
git checkout main
```

### Step 3: Create Infrastructure Code
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
      version = "~> 3.1"
    }
  }
}

# Variables for environment configuration
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Local values
locals {
  name_prefix = "tfc-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform-Cloud"
    Repository  = "terraform-cloud-infrastructure"
    Branch      = terraform.workspace
  }
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = var.environment == "production"
  single_nat_gateway = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Security Group
resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for ${var.environment} application"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-sg"
  })
}

# EC2 Instances
resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>${var.environment} Server ${count.index + 1}</h1>" > /var/www/html/index.html
    echo "<p>Deployed via Terraform Cloud from GitHub</p>" >> /var/www/html/index.html
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-${count.index + 1}"
  })
}

# Random suffix for S3 bucket
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket
resource "aws_s3_bucket" "app_data" {
  bucket = "${local.name_prefix}-data-${random_string.bucket_suffix.result}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-data"
  })
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  
  versioning_configuration {
    status = var.environment == "production" ? "Enabled" : "Suspended"
  }
}
```

**outputs.tf:**
```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "instance_ips" {
  description = "Instance public IPs"
  value       = aws_instance.app[*].public_ip
}

output "s3_bucket" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app_data.id
}

output "environment" {
  description = "Current environment"
  value       = var.environment
}
```

### Step 4: Create Environment-Specific Variable Files
**environments/dev.auto.tfvars:**
```hcl
environment    = "development"
instance_count = 1
instance_type  = "t3.micro"
```

**environments/staging.auto.tfvars:**
```hcl
environment    = "staging"
instance_count = 2
instance_type  = "t3.small"
```

**environments/prod.auto.tfvars:**
```hcl
environment    = "production"
instance_count = 3
instance_type  = "t3.medium"
```

### Step 5: Commit and Push Code
```bash
# Create environments directory
mkdir environments

# Create the variable files
cat > environments/dev.auto.tfvars << 'EOF'
environment    = "development"
instance_count = 1
instance_type  = "t3.micro"
EOF

cat > environments/staging.auto.tfvars << 'EOF'
environment    = "staging"
instance_count = 2
instance_type  = "t3.small"
EOF

cat > environments/prod.auto.tfvars << 'EOF'
environment    = "production"
instance_count = 3
instance_type  = "t3.medium"
EOF

# Add all files
git add .
git commit -m "Initial infrastructure code"
git push origin main
```

---

## 🔗 **Exercise 12.2: Connect GitHub to Terraform Cloud (15 minutes)**

### Step 1: Create Terraform Cloud Organization
1. Log in to [Terraform Cloud](https://app.terraform.io)
2. Create organization if needed: `{username}-org`

### Step 2: Configure VCS Provider
1. Go to **Settings** → **Providers** (in your organization)
2. Click **Add a VCS Provider**
3. Select **GitHub** → **GitHub.com**
4. Follow OAuth flow to authorize Terraform Cloud
5. Grant access to your repositories

### Step 3: Create VCS-Driven Workspace
1. Click **New** → **Workspace**
2. Choose **Version control workflow**
3. Select your GitHub connection
4. Choose your `terraform-cloud-infrastructure` repository
5. Workspace settings:
   - **Name**: `github-triggered-dev`
   - **Description**: "Development environment triggered by GitHub"
   - **Terraform Working Directory**: Leave blank (root)
   - **VCS branch**: `main` (for now)
   - **Automatic Run Triggering**: Enable

### Step 4: Configure Workspace Variables
Add these variables in the workspace:

**Environment Variables:**
- `AWS_ACCESS_KEY_ID` (sensitive)
- `AWS_SECRET_ACCESS_KEY` (sensitive)
- `AWS_DEFAULT_REGION` = `us-east-2`

**Terraform Variables:**
- Click **+ Add variable**
- Key: `environment`, Value: `development`

### Step 5: Test the Integration
```bash
# Make a small change
echo "# Triggered from GitHub" >> README.md
git add README.md
git commit -m "Test GitHub trigger"
git push origin main

# Go to Terraform Cloud and watch the run trigger automatically!
```

---

## 🚀 **Exercise 12.3: Multi-Environment Workflow (15 minutes)**

### Step 1: Create Branch-Based Environments
Create three workspaces in Terraform Cloud, each tracking different branches:

**Development Workspace:**
- Name: `github-dev`
- VCS branch: `development`
- Auto-apply: **Yes** (safe for dev)
- Variable: `environment = development`

**Staging Workspace:**
- Name: `github-staging`
- VCS branch: `staging`
- Auto-apply: **No** (require approval)
- Variable: `environment = staging`

**Production Workspace:**
- Name: `github-prod`
- VCS branch: `main`
- Auto-apply: **No** (require approval)
- Variable: `environment = production`

### Step 2: Configure Branch Protection (GitHub)
1. Go to your GitHub repository
2. Settings → Branches → Add rule
3. Branch name pattern: `main`
4. Enable:
   - Require pull request reviews
   - Require status checks (Terraform Cloud)
   - Dismiss stale reviews
   - Restrict who can push

### Step 3: Create Terraform Cloud Configuration File
**.terraform-cloud.yml:** (in repository root)
```yaml
# Terraform Cloud configuration for GitHub Actions
workspaces:
  - name: github-dev
    directory: "."
    auto_apply: true
    branch: development
    
  - name: github-staging
    directory: "."
    auto_apply: false
    branch: staging
    
  - name: github-prod
    directory: "."
    auto_apply: false
    branch: main
```

### Step 4: Test Multi-Environment Deployment
```bash
# Switch to development branch
git checkout development

# Make a change
cat >> main.tf << 'EOF'

output "deployment_timestamp" {
  description = "Deployment timestamp"
  value       = timestamp()
}
EOF

# Commit and push to development
git add main.tf
git commit -m "Add deployment timestamp"
git push origin development

# Watch Terraform Cloud trigger for dev environment

# Create PR to staging
git checkout staging
git merge development
git push origin staging

# Create PR to main (production)
git checkout main
git pull origin main
git checkout -b feature/deploy-timestamp
git merge staging
git push origin feature/deploy-timestamp

# Go to GitHub and create Pull Request
# Watch Terraform Cloud run checks on the PR
```

---

## 🔧 **Exercise 12.4: Advanced GitHub Integration (5 minutes)**

### Step 1: Add Status Badges
Add to **README.md:**
```markdown
# Terraform Cloud Infrastructure

## Deployment Status
![Development](https://app.terraform.io/api/v2/organizations/YOUR_ORG/workspaces/github-dev/current-run/badge)
![Staging](https://app.terraform.io/api/v2/organizations/YOUR_ORG/workspaces/github-staging/current-run/badge)
![Production](https://app.terraform.io/api/v2/organizations/YOUR_ORG/workspaces/github-prod/current-run/badge)

## Overview
Infrastructure as Code managed through Terraform Cloud with GitHub integration.

### Workflow
1. Development changes pushed to `development` branch
2. Auto-deployed to development environment
3. PR to `staging` branch for staging deployment
4. PR to `main` branch for production deployment
5. Manual approval required for staging and production

### Environments
- **Development**: Auto-deploy on push
- **Staging**: Manual approval required
- **Production**: Manual approval + PR review required
```

### Step 2: Create Deployment Checklist
**DEPLOYMENT.md:**
```markdown
# Deployment Checklist

## Pre-Deployment
- [ ] Code reviewed and approved
- [ ] Tests passing
- [ ] Security scan completed
- [ ] Cost estimation reviewed

## Deployment Steps
1. Merge to target branch
2. Terraform Cloud runs plan
3. Review plan output
4. Approve apply (staging/prod)
5. Monitor deployment

## Post-Deployment
- [ ] Verify application health
- [ ] Check monitoring dashboards
- [ ] Update documentation
- [ ] Notify stakeholders
```

### Step 3: Commit Documentation
```bash
git add README.md DEPLOYMENT.md
git commit -m "Add deployment documentation and status badges"
git push origin main
```

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **GitHub Integration** - Connected repository to Terraform Cloud  
✅ **VCS-Driven Workflow** - Automatic triggers on Git push  
✅ **Branch-Based Environments** - Dev, staging, prod from branches  
✅ **PR Automation** - Terraform plans on pull requests  
✅ **GitOps Pattern** - Git as single source of truth  
✅ **Status Visibility** - Badges and deployment tracking  

### Key Concepts Learned
- **VCS Integration**: Connecting Git providers to Terraform Cloud
- **Trigger Patterns**: Push, PR, and tag-based deployments
- **Branch Strategies**: Environment management via branches
- **Approval Workflows**: Manual gates for production
- **GitOps Principles**: Declarative infrastructure via Git

### GitHub-Terraform Cloud Flow
```
Developer Push → GitHub → Webhook → Terraform Cloud → Plan → Apply
                    ↓                                          ↓
                PR Checks                              Infrastructure
```

---

## 🧹 **Cleanup**
```bash
# In Terraform Cloud:
# 1. Go to each workspace
# 2. Settings → Destruction and Deletion
# 3. Queue destroy plan
# 4. Approve destruction

# In GitHub:
# Keep repository for future reference or delete if desired
```

---

## 🎓 **Congratulations!**
You've completed the Terraform course! You now have hands-on experience with:
- **Core Terraform concepts** and HCL syntax
- **Module development** and composition
- **State management** and backends
- **Multi-environment** patterns
- **Terraform Cloud** enterprise features
- **GitOps workflows** with GitHub integration

### Next Steps
- Explore Terraform Cloud's advanced features (Sentinel policies, cost estimation)
- Implement this pattern in your own projects
- Consider HashiCorp Terraform certification
- Join the Terraform community and contribute to modules

**Well done on completing your Terraform journey!** 🎉