# Lab 8: Multi-Environment Deployment Patterns
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Implement multi-environment deployments using tfvars files
- Design environment-specific configurations without workspaces
- Create reusable infrastructure code that adapts to different environments
- Apply environment-specific scaling and feature flags
- Manage cost optimization across different deployment stages

---

## 📋 **Prerequisites**
- Completion of Labs 2-7
- Understanding of variables and modules
- State management concepts from Lab 6
- Registry modules knowledge from Lab 7

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# Your username was saved by setup.sh in Lab 1 — confirm it is set
echo "Username: $TF_VAR_username"
```

> If it prints nothing, run `source ~/.bashrc`. If it shows the wrong name, re-run `bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <your-username>` and then `source ~/.bashrc`. Do **not** `export` a different value — every resource name includes it.

> All resources deploy to **us-east-2** — `aws_region` defaults to `"us-east-2"` in `variables.tf`, so you don't need to set it.

---

## 🏗️ **Exercise 8.1: Environment-Agnostic Infrastructure (20 minutes)**

### Step 1: Navigate to Lab Directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab08
```

### Step 2: Review the Environment-Flexible Configuration
This infrastructure code adapts to different environments using variable files. The architecture uses Launch Templates and Auto Scaling Groups for scalable compute, with a conditional Application Load Balancer for high-availability environments.

This lab ships with a complete configuration — every file and block shown below (`variables.tf`, `user_data.sh`, `main.tf`, `outputs.tf`, and `environments/*.tfvars`) is **already in the lab directory**. Don't add or paste anything; open each file in the Cloud9 editor and read along. (Pasting a block a second time would cause a `Duplicate resource` or `Duplicate variable declaration` error.)

**variables.tf:**
```hcl
variable "username" {
  description = "Your unique username"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters: lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}

variable "enable_high_availability" {
  description = "Enable high availability configuration"
  type        = bool
  default     = false
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cost_optimization" {
  description = "Cost optimization settings"
  type = object({
    use_spot_instances = bool
    enable_auto_stop   = bool
    max_price          = number
  })
  default = {
    use_spot_instances = false
    enable_auto_stop   = false
    max_price          = 0.05
  }
}
```

### Step 3: Review the User Data Script
The application servers use an external user data script loaded via `templatefile()`.

**user_data.sh:**
```bash
#!/bin/bash
yum update -y
yum install -y httpd

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Amazon Linux 2023 requires IMDSv2: fetch a session token first, then pass it
# on every instance metadata request
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create environment-specific content
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>${environment} Environment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #232f3e; color: white; padding: 20px; }
        .content { padding: 20px; }
        .env-${environment} { border-left: 5px solid #ff9900; padding-left: 15px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Multi-Environment Demo</h1>
        <h2>Environment: ${environment}</h2>
    </div>
    <div class="content">
        <div class="env-${environment}">
            <h3>Server Information</h3>
            <p><strong>Owner:</strong> ${username}</p>
            <p><strong>Environment:</strong> ${environment}</p>
            <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
            <p><strong>Availability Zone:</strong> $AZ</p>
            <p><strong>Server Time:</strong> $(date)</p>
        </div>
    </div>
</body>
</html>
EOF
```

### Step 4: Review the Main Configuration
This configuration uses Launch Templates and Auto Scaling Groups (rather than direct EC2 instances) for better scalability. An Application Load Balancer is conditionally created when `var.enable_high_availability` is enabled.

**main.tf:**
```hcl
terraform {
  required_version = ">= 1.9"

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

  # Using local backend for this lab
  # In production, you would use remote state per environment
}

provider "aws" {
  region = var.aws_region
}

# Local values for environment-specific logic
locals {
  name_prefix = "${var.username}-${var.environment}"

  # Environment-specific settings
  availability_zones = var.enable_high_availability ? slice(data.aws_availability_zones.available.names, 0, 2) : slice(data.aws_availability_zones.available.names, 0, 1)

  backup_retention = var.environment == "prod" ? 30 : (var.environment == "staging" ? 7 : 1)

  use_private_subnets = var.environment != "dev"

  common_tags = {
    Owner       = var.username
    Environment = var.environment
    Project     = "MultiEnvironment"
    ManagedBy   = "Terraform"
    Lab         = "8"
  }
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
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# VPC Module - environment-aware configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs = local.availability_zones

  # Environment-specific subnet configuration
  private_subnets = local.use_private_subnets ? [
    for i, az in local.availability_zones : "10.0.${i + 1}.0/24"
  ] : []

  public_subnets = [
    for i, az in local.availability_zones : "10.0.${i + 101}.0/24"
  ]

  # dev runs its instances in the public subnets (no NAT gateway), so they
  # need a public IP to reach the internet for the user_data package install.
  # VPC module v5 defaults this to false.
  map_public_ip_on_launch = true

  # NAT Gateway only for non-dev environments
  enable_nat_gateway = local.use_private_subnets
  single_nat_gateway = var.environment != "prod" # Multiple NAT gateways only in prod

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Security group with environment-specific rules
resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  description = "Security group for application servers"
  vpc_id      = module.vpc.vpc_id

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # SSH access (restricted in production)
  dynamic "ingress" {
    for_each = var.environment == "prod" ? [] : [1]
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# Launch Template for environment-specific configuration
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  # Use spot instances if configured
  dynamic "instance_market_options" {
    for_each = var.cost_optimization.use_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = var.cost_optimization.max_price
      }
    }
  }

  monitoring {
    enabled = var.enable_monitoring
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    username    = var.username
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Type = "ApplicationServer"
    })
  }

  tags = local.common_tags
}

# Auto Scaling Group for resilience
resource "aws_autoscaling_group" "app" {
  name                = "${local.name_prefix}-asg"
  vpc_zone_identifier = local.use_private_subnets ? module.vpc.private_subnets : module.vpc.public_subnets
  target_group_arns   = var.enable_high_availability ? [aws_lb_target_group.app[0].arn] : []

  min_size         = 1
  max_size         = var.enable_high_availability ? var.instance_count * 2 : var.instance_count
  desired_capacity = var.instance_count

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Health checks
  health_check_type         = var.enable_high_availability ? "ELB" : "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Load Balancer for high availability environments
resource "aws_lb" "app" {
  count = var.enable_high_availability ? 1 : 0

  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = module.vpc.public_subnets

  tags = local.common_tags
}

resource "aws_lb_target_group" "app" {
  count = var.enable_high_availability ? 1 : 0

  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "app" {
  count = var.enable_high_availability ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
}
```

> **Key Concept:** In `dev`, there are no private subnets or NAT gateway, so the Auto Scaling Group launches instances into the **public** subnets. `map_public_ip_on_launch = true` gives those instances a public IP so they can reach the internet to install Apache — without it (the VPC module's default is `false`), the `user_data` package install would fail.

### Step 5: Review the Output Configuration
**outputs.tf:**
```hcl
output "environment_info" {
  description = "Environment configuration details"
  value = {
    name                  = var.environment
    instance_type         = var.instance_type
    instance_count        = var.instance_count
    high_availability     = var.enable_high_availability
    monitoring_enabled    = var.enable_monitoring
    backups_enabled       = var.enable_backups
    backup_retention_days = local.backup_retention
  }
}

output "vpc_info" {
  description = "VPC configuration"
  value = {
    vpc_id            = module.vpc.vpc_id
    private_subnets   = module.vpc.private_subnets
    public_subnets    = module.vpc.public_subnets
    using_nat_gateway = local.use_private_subnets
  }
}

output "application_endpoint" {
  description = "Application endpoint URL"
  value       = var.enable_high_availability ? "http://${aws_lb.app[0].dns_name}" : (local.use_private_subnets ? "No load balancer - instances run in private subnets" : "No load balancer - in the EC2 console, filter instances by tag Owner = ${var.username} and browse to the public IP")
}

output "security_groups" {
  description = "Security group information"
  value = {
    app_security_group_id = aws_security_group.app.id
  }
}

output "cost_optimization" {
  description = "Cost optimization settings applied"
  value       = var.cost_optimization
}
```

---

## 🚀 **Exercise 8.2: Environment-Specific Configurations (10 minutes)**

### Step 1: Review the Default Variable File
The shipped `terraform.tfvars` contains only comments — it deliberately sets **no** values. Your `username` comes from the `TF_VAR_username` environment variable that `setup.sh` saved in Lab 1, and `aws_region` uses its `us-east-2` default. Environment-specific settings are loaded separately via `-var-file`.

> **Do not add `username` to `terraform.tfvars`.** Values in `terraform.tfvars` override `TF_VAR_*` environment variables, so a hard-coded `username = "user1"` would make every student collide on the same resource names in the shared AWS account.

### Step 2: Review the Development Environment Configuration
**environments/dev.tfvars:**
```hcl
# Development Environment Configuration
environment              = "dev"
instance_type            = "t3.micro"
instance_count           = 1
enable_monitoring        = false
enable_backups           = false
enable_high_availability = false
allowed_cidrs            = ["0.0.0.0/0"] # Open for development

cost_optimization = {
  use_spot_instances = true # Use spot instances to save costs
  enable_auto_stop   = true
  max_price          = 0.01
}
```

### Step 3: Review the Staging Environment Configuration
**environments/staging.tfvars:**
```hcl
# Staging Environment Configuration
environment              = "staging"
instance_type            = "t3.small"
instance_count           = 2
enable_monitoring        = true
enable_backups           = true
enable_high_availability = false
allowed_cidrs = [
  "10.0.0.0/8",   # Internal network
  "172.16.0.0/12" # VPN range
]

cost_optimization = {
  use_spot_instances = false # More stable for staging
  enable_auto_stop   = false
  max_price          = 0.05
}
```

### Step 4: Review the Production Environment Configuration
**environments/prod.tfvars:**
```hcl
# Production Environment Configuration
environment              = "prod"
instance_type            = "t3.medium"
instance_count           = 3
enable_monitoring        = true
enable_backups           = true
enable_high_availability = true
allowed_cidrs = [
  "10.0.0.0/8" # Only internal network
]

cost_optimization = {
  use_spot_instances = false # Never use spot in production
  enable_auto_stop   = false
  max_price          = 0.10
}
```

### Step 5: Deploy the Development Environment
Your `username` comes from `TF_VAR_username`. You pass the environment-specific file with `-var-file` to supply the remaining variables.

```bash
# Confirm your username is set
echo "Username: $TF_VAR_username"

# The environment tfvars files from Steps 2-4 are already in environments/
ls environments/

# Initialize Terraform
terraform init

# Deploy development environment
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars -auto-approve
```

---

## 🔄 **Exercise 8.3: Compare Environments (5 minutes)**

You don't need to deploy staging or prod to *see* what each environment would create — `terraform plan -var-file` shows the diff.

### Step 1: Inspect Differences Without Applying
```bash
# What's currently deployed (dev)?
terraform output

# What would change if you switched to staging?
terraform plan -var-file=environments/staging.tfvars

# What would change for production?
terraform plan -var-file=environments/prod.tfvars
```

The plan output shows resource-by-resource differences. Look for:
- **Instance type changes** (`t3.micro` → `t3.small` → `t3.medium`)
- **ASG desired_capacity changes** (1 → 2 → 3)
- **ALB resources** that appear only in production (HA enabled)
- **Replacements (`-/+`)** for the Auto Scaling Group, launch template, and security group — their names (`name` / `name_prefix`) include the environment, and AWS can't rename those resources in place, so Terraform must destroy and recreate them

> **Note:** Those replacements appear only because you are planning staging and prod against the **dev** state file. In a real project each environment keeps its own state (separate backend key or directory), so switching `-var-file` would create a separate stack rather than replace dev. Don't apply these plans — just read them.

> **Why this matters:** the same Terraform code produces three different deployments. The only thing that varies is the variable file. This is the multi-environment pattern in its simplest form — no workspaces, no separate directories.

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **Multi-environment patterns** - Created flexible infrastructure for dev/staging/prod  
✅ **Environment-specific tfvars** - Managed configurations without workspaces  
✅ **Conditional resources** - Deployed resources based on environment needs  
✅ **Cost optimization** - Applied different cost strategies per environment  
✅ **Security controls** - Environment-appropriate security settings  

### Key Concepts Learned
- **Variable files**: Using tfvars for environment separation
- **Conditional logic**: Dynamic resources based on variables
- **Environment patterns**: Dev vs Staging vs Production requirements
- **Cost management**: Environment-appropriate resource sizing
- **Security layers**: Progressive security hardening

### Environment Differences Applied
| Feature | Development | Staging | Production |
|---------|------------|---------|------------|
| Instance Type | t3.micro | t3.small | t3.medium |
| ASG Desired Capacity | 1 | 2 | 3 |
| High Availability | ❌ | ❌ | ✅ |
| Monitoring | ❌ | ✅ | ✅ |
| Backups | ❌ | ✅ | ✅ |
| Spot Instances | ✅ | ❌ | ❌ |
| SSH Access | ✅ | ✅ | ❌ |

---

## 🧹 **Cleanup**
```bash
# Destroy the development environment
terraform destroy -var-file=environments/dev.tfvars
```

---

## 🎓 **Next Steps**
In **Lab 9**, we'll explore **advanced networking with VPC** to build a two-tier network architecture.

**Key topics coming up:**
- Multi-tier VPC design
- Advanced routing and NAT
- Network security layers
- Application Load Balancer with health checks and target groups
