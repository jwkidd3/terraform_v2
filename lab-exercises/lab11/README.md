# Lab 11: Terraform Cloud Workspaces
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 3
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Create and manage multiple Terraform Cloud workspaces
- Use the `cloud {}` block with `tags` to select workspaces from the CLI
- Configure workspace-specific variables for different environments
- Organize workspaces with tags and naming conventions
- Deploy the same configuration to multiple environments

---

## 📋 **Prerequisites**
- Completion of Lab 10 (Terraform Cloud Integration)
- Terraform Cloud account with organization from Lab 10
- Authenticated with `terraform login` (from Lab 10)

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 11.1: Create Shared Configuration (10 minutes)**

In this exercise, you will create a single Terraform configuration that can be deployed to multiple Terraform Cloud workspaces. The key is the `cloud {}` block using `tags` instead of `name` — this allows you to switch between workspaces with `terraform workspace select`.

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab11
cd terraform-lab11
```

### Step 2: Create Configuration Files

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
    organization = "user1-terraform-training"  # Replace with your org name from Lab 10

    workspaces {
      tags = ["lab11"]  # Selects among all workspaces tagged "lab11"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

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

variable "username" {
  description = "Your unique username"
  type        = string
}

# EC2 instances
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name        = "${var.username}-${var.environment}-instance-${count.index + 1}"
    Environment = var.environment
    Owner       = var.username
  }
}
```

**outputs.tf:**
```hcl
output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.app[*].id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
```

Create both files in your `terraform-lab11` directory with the content above.

> **Key Concept — `tags` vs `name` in the `cloud {}` block:**
> - Using `workspaces { name = "..." }` locks you to a single workspace.
> - Using `workspaces { tags = ["..."] }` lets you select among any workspace that has that tag. This is what enables `terraform workspace select` to switch between workspaces.

---

## ☁️ **Exercise 11.2: Create Development Workspace (10 minutes)**

### Step 1: Create Development Workspace in Terraform Cloud
1. Go to Terraform Cloud: https://app.terraform.io
2. In your organization, click **New Workspace**
3. Choose **CLI-driven workflow**
4. Workspace name: `lab11-development`
5. Description: "Development environment workspace"
6. Click **Create workspace**

### Step 2: Configure Workspace Variables
In the workspace, go to the **Variables** tab.

Add these **Environment Variables** (needed for AWS access):
- `AWS_ACCESS_KEY_ID` (mark as **sensitive**)
- `AWS_SECRET_ACCESS_KEY` (mark as **sensitive**)
- `AWS_DEFAULT_REGION` = `us-east-2`

Add these **Terraform Variables**:
- `username` = your assigned username (e.g., `user1`)
- `environment` = `development`
- `instance_count` = `1`

> **Key Concept — Environment Variables vs Terraform Variables:**
> - **Environment Variables** are passed to the execution environment (like `export` in a shell). AWS credentials go here.
> - **Terraform Variables** map to your `variable` blocks in HCL. Configuration values go here.

### Step 3: Tag the Workspace
1. Go to **Settings** → **General**
2. In the **Tags** section, add: `lab11`
3. Also add: `environment:development`
4. Set **Execution Mode**: Remote (default)
5. Set **Apply Method**: Manual apply (safer for learning)

> **Important:** The `lab11` tag is what connects this workspace to your `cloud {}` block. Without it, `terraform workspace select` won't find this workspace.

---

## 🚀 **Exercise 11.3: Create Staging Workspace (10 minutes)**

### Step 1: Create Staging Workspace
1. Click **New Workspace**
2. Choose **CLI-driven workflow**
3. Workspace name: `lab11-staging`
4. Description: "Staging environment workspace"
5. Click **Create workspace**

### Step 2: Configure Different Variables
Add **Environment Variables** (same credentials as development):
- `AWS_ACCESS_KEY_ID` (mark as **sensitive**)
- `AWS_SECRET_ACCESS_KEY` (mark as **sensitive**)
- `AWS_DEFAULT_REGION` = `us-east-2`

Add **Terraform Variables** (different values from development):
- `username` = your assigned username (e.g., `user1`)
- `environment` = `staging`
- `instance_count` = `2`

### Step 3: Tag the Staging Workspace
1. **Settings** → **General**
2. Add tags: `lab11`, `environment:staging`

> **Notice:** Both workspaces have the `lab11` tag — this is how Terraform knows they belong to the same configuration. The `environment:*` tags are for your own organization.

---

## 🔧 **Exercise 11.4: Deploy and Compare Workspaces (15 minutes)**

### Step 1: Initialize and Select Development Workspace
```bash
cd ~/environment/terraform-lab11

# Initialize — Terraform will find both workspaces tagged "lab11"
terraform init

# List available workspaces
terraform workspace list

# Select the development workspace
terraform workspace select lab11-development
```

You should see both `lab11-development` and `lab11-staging` in the workspace list.

### Step 2: Deploy to Development
```bash
# Plan — runs remotely in Terraform Cloud
terraform plan

# Apply — runs remotely in Terraform Cloud
terraform apply
```

Review the plan output. You should see:
- 1 EC2 instance (`instance_count = 1`)

Approve the apply when prompted (or confirm in the Terraform Cloud UI).

### Step 3: Deploy to Staging
```bash
# Switch to the staging workspace
terraform workspace select lab11-staging

# Plan and apply
terraform plan
terraform apply
```

Review the plan. You should see:
- 2 EC2 instances (`instance_count = 2`)

### Step 4: Compare Workspaces
In the Terraform Cloud UI, compare the two workspaces:

1. **Resources**: Development has 1 instance, staging has 2
2. **Variables** tab: Different `environment` and `instance_count` values
3. **State** tab: Each workspace has its own independent state file
4. **Tags**: Both share `lab11`, but differ on `environment:*`
5. **Runs** tab: Each workspace has its own run history

```bash
# Show current workspace
terraform workspace show

# Switch back and check outputs from each
terraform workspace select lab11-development
terraform output

terraform workspace select lab11-staging
terraform output
```

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **Cloud Block with Tags** — Used `workspaces { tags = ["lab11"] }` for multi-workspace selection
✅ **Multiple Workspaces** — Created development and staging workspaces
✅ **Workspace Variables** — Configured environment-specific variables in each workspace
✅ **Workspace Organization** — Used tags for workspace management
✅ **Environment Separation** — Deployed different configurations per environment from the same code

### Key Concepts Learned
- **Workspace Isolation**: Each workspace has its own state, variables, and run history
- **Tag-Based Selection**: The `cloud { workspaces { tags } }` block lets you switch workspaces with `terraform workspace select`
- **Variable Hierarchy**: Environment variables (AWS creds) vs Terraform variables (configuration)
- **Same Code, Different Config**: One codebase deployed to multiple environments via workspace variables

### Workspace Benefits
- **State Isolation**: No risk of accidentally affecting other environments
- **Variable Management**: Environment-specific configurations managed in the UI
- **Audit Trail**: Complete run history per workspace
- **Team Organization**: Clear separation by environment
- **Access Control**: Fine-grained permissions per workspace (available in paid tiers)

---

## 🧹 **Cleanup**
```bash
# Destroy resources in both workspaces
terraform workspace select lab11-development
terraform destroy

terraform workspace select lab11-staging
terraform destroy
```

Type `yes` when prompted to confirm destruction for each workspace.

---

## 🎓 **Next Steps**
In **Lab 12**, you will explore **VCS-driven workflows** — connecting a GitHub repository to Terraform Cloud so that Git pushes automatically trigger infrastructure deployments.

**Key topics coming up:**
- GitHub repository integration with Terraform Cloud
- Webhook-triggered runs on Git push
- Speculative plans on pull requests
- GitOps patterns for infrastructure automation
