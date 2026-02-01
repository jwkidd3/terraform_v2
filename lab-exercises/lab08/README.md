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
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 8.1: Environment-Agnostic Infrastructure (20 minutes)**

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab8
cd terraform-lab8
```

### Step 2: Design Environment-Flexible Configuration
We'll create infrastructure code that adapts to different environments using variable files. The architecture uses Launch Templates and Auto Scaling Groups for scalable compute, with a conditional Application Load Balancer for high-availability environments.

**variables.tf:**
```hcl
variable "username" {
  description = "Your unique username"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters, lowercase letters and numbers only."
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
    max_price         = number
  })
  default = {
    use_spot_instances = false
    enable_auto_stop   = false
    max_price         = 0.05
  }
}
```

### Step 3: Create User Data Script
The application servers use an external user data script loaded via `templatefile()`.

**user_data.sh:**
```bash
#!/bin/bash
yum update -y
yum install -y httpd

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

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
            <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
            <p><strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
            <p><strong>Server Time:</strong> $(date)</p>
        </div>
    </div>
</body>
</html>
EOF
```

### Step 4: Create Main Configuration
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
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
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

  # NAT Gateway only for non-dev environments
  enable_nat_gateway = local.use_private_subnets
  single_nat_gateway = var.environment != "prod"  # Multiple NAT gateways only in prod

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

### Step 5: Create Output Configuration
**outputs.tf:**
```hcl
output "environment_info" {
  description = "Environment configuration details"
  value = {
    name                    = var.environment
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    high_availability      = var.enable_high_availability
    monitoring_enabled     = var.enable_monitoring
    backups_enabled        = var.enable_backups
    backup_retention_days  = local.backup_retention
  }
}

output "vpc_info" {
  description = "VPC configuration"
  value = {
    vpc_id             = module.vpc.vpc_id
    private_subnets    = module.vpc.private_subnets
    public_subnets     = module.vpc.public_subnets
    using_nat_gateway  = local.use_private_subnets
  }
}

output "application_endpoint" {
  description = "Application endpoint URL"
  value = var.enable_high_availability ? "http://${aws_lb.app[0].dns_name}" : "Check EC2 instances for public IPs"
}

output "security_groups" {
  description = "Security group information"
  value = {
    app_security_group_id = aws_security_group.app.id
  }
}

output "cost_optimization" {
  description = "Cost optimization settings applied"
  value = var.cost_optimization
}
```

---

## 🚀 **Exercise 8.2: Environment-Specific Configurations (10 minutes)**

### Step 1: Create the Default Variable File
The `terraform.tfvars` file sets the default username. Environment-specific settings are loaded separately via `-var-file`.

**terraform.tfvars:**
```hcl
username = "user1"  # Replace with your username
```

### Step 2: Create Development Environment Configuration
**environments/dev.tfvars:**
```hcl
# Development Environment Configuration
environment               = "dev"
instance_type            = "t3.micro"
instance_count           = 1
enable_monitoring        = false
enable_backups          = false
enable_high_availability = false
allowed_cidrs = ["0.0.0.0/0"]  # Open for development

cost_optimization = {
  use_spot_instances = true   # Use spot instances to save costs
  enable_auto_stop   = true
  max_price         = 0.01
}
```

### Step 3: Create Staging Environment Configuration
**environments/staging.tfvars:**
```hcl
# Staging Environment Configuration
environment               = "staging"
instance_type            = "t3.small"
instance_count           = 2
enable_monitoring        = true
enable_backups          = true
enable_high_availability = false
allowed_cidrs = [
  "10.0.0.0/8",     # Internal network
  "172.16.0.0/12"   # VPN range
]

cost_optimization = {
  use_spot_instances = false  # More stable for staging
  enable_auto_stop   = false
  max_price         = 0.05
}
```

### Step 4: Create Production Environment Configuration
**environments/prod.tfvars:**
```hcl
# Production Environment Configuration
environment               = "prod"
instance_type            = "t3.medium"
instance_count           = 3
enable_monitoring        = true
enable_backups          = true
enable_high_availability = true
allowed_cidrs = [
  "10.0.0.0/8"      # Only internal network
]

cost_optimization = {
  use_spot_instances = false  # Never use spot in production
  enable_auto_stop   = false
  max_price         = 0.10
}
```

### Step 5: Create and Deploy Environments
The `terraform.tfvars` file is loaded automatically, providing the `username`. You then pass the environment-specific file with `-var-file` to supply the remaining variables.

```bash
# Create the environment tfvars files with the content from Steps 2-4 above

# Initialize Terraform
terraform init

# Deploy development environment
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars -auto-approve
```

---

## 🔄 **Exercise 8.3: Environment Management Automation (15 minutes)**

### Step 1: Test Environment Switching
```bash
# View current development deployment
terraform output

# Compare what would change for staging (without applying)
echo "\n=== Comparing staging environment ==="
terraform plan -var-file=environments/staging.tfvars | grep -E "will be|must be"

# View environment differences
echo "\n=== Environment Resource Comparison ==="
echo "Development:  t3.micro,  ASG desired=1, no HA,  spot instances"
echo "Staging:      t3.small,  ASG desired=2, no HA,  on-demand"
echo "Production:   t3.medium, ASG desired=3, with HA + ALB"
```

### Step 2: Create Environment Management Script
**deploy.sh:**
```bash
#!/bin/bash
# Simple deployment script for multi-environment management

ENVIRONMENT=$1
USERNAME=$2

if [ -z "$ENVIRONMENT" ] || [ -z "$USERNAME" ]; then
    echo "Usage: ./deploy.sh <environment> <username>"
    echo "Environments: dev, staging, prod"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
fi

# Set username
export TF_VAR_username=$USERNAME

# Select the appropriate tfvars file
TFVARS_FILE="environments/${ENVIRONMENT}.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
    echo "Error: Configuration file $TFVARS_FILE not found"
    exit 1
fi

echo "==================================="
echo "Deploying to: $ENVIRONMENT"
echo "Username: $USERNAME"
echo "Configuration: $TFVARS_FILE"
echo "==================================="

# Initialize if needed
if [ ! -d ".terraform" ]; then
    terraform init
fi

# Plan the deployment
terraform plan -var-file="$TFVARS_FILE" -out="${ENVIRONMENT}.tfplan"

# Ask for confirmation
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    terraform apply "${ENVIRONMENT}.tfplan"
    echo "Deployment complete!"
else
    echo "Deployment cancelled"
fi
```

### Step 3: Make Script Executable and Test
```bash
chmod +x deploy.sh

# Test the deployment script
./deploy.sh dev $TF_VAR_username
# When prompted, type 'no' to skip the actual deployment
```

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **Multi-environment patterns** - Created flexible infrastructure for dev/staging/prod  
✅ **Environment-specific tfvars** - Managed configurations without workspaces  
✅ **Conditional resources** - Deployed resources based on environment needs  
✅ **Cost optimization** - Applied different cost strategies per environment  
✅ **Security controls** - Environment-appropriate security settings  
✅ **Deployment automation** - Created reusable deployment scripts  

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
In **Lab 9**, we'll explore **advanced networking with VPC** to build production-ready network architectures.

**Key topics coming up:**
- Multi-tier VPC design
- Advanced routing and NAT
- Network security layers
- VPC peering and endpoints
