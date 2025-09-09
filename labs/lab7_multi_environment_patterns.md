# Lab 7: Multi-Environment Deployment Patterns
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
- Completion of Labs 1-6
- Understanding of variables and modules
- Remote state setup from Lab 5
- Registry modules knowledge from Lab 6

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 7.1: Environment-Agnostic Infrastructure (20 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab7
cd terraform-lab7
```

### Step 2: Design Environment-Flexible Configuration
We'll create infrastructure code that adapts to different environments using variable files.

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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of instances to deploy"
  type        = number
  default     = 1
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = false
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}

variable "enable_high_availability" {
  description = "Enable high availability features"
  type        = bool
  default     = false
}

variable "allowed_cidrs" {
  description = "List of allowed CIDR blocks for access"
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

### Step 3: Create Main Configuration
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
  
  # Using local backend for this lab
  # In production, you would use remote state per environment
}

provider "aws" {
  region = "us-east-2"
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

# Local values with environment-specific logic
locals {
  name_prefix = "${var.username}-${var.environment}"
  
  # Environment-specific tags
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    ManagedBy   = "Terraform"
    Lab         = "7"
    CostCenter  = var.environment == "prod" ? "production" : "development"
  }
  
  # Determine subnet placement based on environment
  use_private_subnets = var.environment == "prod" ? true : false
  
  # Set backup configuration based on environment
  backup_retention = var.enable_backups ? (
    var.environment == "prod" ? 30 : 
    var.environment == "staging" ? 7 : 
    1
  ) : 0
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, var.enable_high_availability ? 3 : 1)
  private_subnets = var.enable_high_availability ? ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] : ["10.0.1.0/24"]
  public_subnets  = var.enable_high_availability ? ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"] : ["10.0.101.0/24"]

  # NAT Gateway configuration based on environment
  enable_nat_gateway = local.use_private_subnets
  single_nat_gateway = !var.enable_high_availability
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Security Group
resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for application servers in ${var.environment}"

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # SSH access only in non-production environments
  dynamic "ingress" {
    for_each = var.environment != "prod" ? [1] : []
    content {
      description = "SSH for debugging"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
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

# EC2 Instances with environment-specific configuration
resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  # Use private subnets in production, public in dev/staging
  subnet_id = local.use_private_subnets ? 
    module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)] :
    module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  
  vpc_security_group_ids = [aws_security_group.app.id]
  
  # Enable monitoring based on environment
  monitoring = var.enable_monitoring
  
  # Use spot instances if cost optimization is enabled
  dynamic "instance_market_options" {
    for_each = var.cost_optimization.use_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = var.cost_optimization.max_price
      }
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    
    # Environment-specific configuration
    echo "Environment: ${var.environment}" > /var/www/html/info.txt
    echo "Instance: ${count.index + 1}" >> /var/www/html/info.txt
    echo "High Availability: ${var.enable_high_availability}" >> /var/www/html/info.txt
    
    # Create a simple HTML page
    cat > /var/www/html/index.html <<HTML
    <html>
      <head><title>${var.environment} Server</title></head>
      <body>
        <h1>Environment: ${var.environment}</h1>
        <h2>Instance ${count.index + 1} of ${var.instance_count}</h2>
        <p>Owner: ${var.username}</p>
        <p>Monitoring: ${var.enable_monitoring ? "Enabled" : "Disabled"}</p>
        <p>Backups: ${var.enable_backups ? "Enabled" : "Disabled"}</p>
      </body>
    </html>
    HTML
    
    systemctl start httpd
    systemctl enable httpd
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-${count.index + 1}"
    Type = "ApplicationServer"
  })
}

# Application Load Balancer (only if high availability is enabled)
resource "aws_lb" "app" {
  count = var.enable_high_availability ? 1 : 0

  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets           = module.vpc.public_subnets

  enable_deletion_protection = var.environment == "prod"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
    Type = "LoadBalancer"
  })
}

# S3 Bucket for application data with environment-specific settings
resource "aws_s3_bucket" "app_data" {
  bucket = "${local.name_prefix}-app-data-${random_string.bucket_suffix.result}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-data"
    Type = "ApplicationData"
  })
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  
  versioning_configuration {
    status = var.enable_backups ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "app_data" {
  count = var.enable_backups ? 1 : 0
  
  bucket = aws_s3_bucket.app_data.id

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"

    transition {
      days          = var.environment == "prod" ? 30 : 7
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = local.backup_retention
    }
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
```

### Step 4: Create Output Configuration
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

output "application_instances" {
  description = "Application server details"
  value = {
    for i, instance in aws_instance.app : 
    "instance-${i + 1}" => {
      id         = instance.id
      private_ip = instance.private_ip
      public_ip  = instance.public_ip
      subnet_id  = instance.subnet_id
    }
  }
}

output "s3_bucket" {
  description = "S3 bucket for application data"
  value = {
    bucket_name = aws_s3_bucket.app_data.id
    bucket_arn  = aws_s3_bucket.app_data.arn
    versioning  = var.enable_backups ? "Enabled" : "Disabled"
  }
}

output "load_balancer_dns" {
  description = "Load balancer DNS (if enabled)"
  value       = var.enable_high_availability ? aws_lb.app[0].dns_name : "N/A - High availability not enabled"
}
```

---

## 🚀 **Exercise 7.2: Environment-Specific Configurations (15 minutes)**

### Step 1: Create Development Environment Configuration
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

### Step 2: Create Staging Environment Configuration
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

### Step 3: Create Production Environment Configuration
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

### Step 4: Deploy Development Environment
```bash
# Create environments directory
mkdir environments

# Create the tfvars files (copy the content above)
cat > environments/dev.tfvars << 'EOF'
# Development Environment Configuration
environment               = "dev"
instance_type            = "t3.micro"
instance_count           = 1
enable_monitoring        = false
enable_backups          = false
enable_high_availability = false

allowed_cidrs = ["0.0.0.0/0"]

cost_optimization = {
  use_spot_instances = true
  enable_auto_stop   = true
  max_price         = 0.01
}
EOF

# Initialize Terraform
terraform init

# Deploy development environment
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

---

## 🔄 **Exercise 7.3: Environment Management and Testing (10 minutes)**

### Step 1: Test Environment Switching
```bash
# View current development deployment
terraform output

# Plan staging environment (without applying)
terraform plan -var-file=environments/staging.tfvars

# See the differences between environments
echo "=== Environment Comparison ==="
echo "Dev uses: t3.micro with 1 instance"
echo "Staging uses: t3.small with 2 instances"
echo "Prod uses: t3.medium with 3 instances and HA"
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

# Test the deployment script (don't apply)
./deploy.sh dev $TF_VAR_username
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
| Instance Count | 1 | 2 | 3 |
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
In **Lab 8**, we'll explore **advanced networking with VPC** to build production-ready network architectures.

**Key topics coming up:**
- Multi-tier VPC design
- Advanced routing and NAT
- Network security layers
- VPC peering and endpoints