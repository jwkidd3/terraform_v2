# Lab 4: Creating and Using Terraform Modules
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
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
- `user1-modular-app-dev-vpc` (VPC)
- `user1-modular-app-dev-web-1` (web instances)
- `terraform-user1.tfstate` (state file)

---

## Lab Objectives
By the end of this lab, you will be able to:
- Create reusable Terraform modules
- Structure modules with proper input/output interfaces
- Compose modules to build complex infrastructure
- Use module versioning and sources

---

## Prerequisites
- Completion of Labs 1-3
- Understanding of resource dependencies and variables
- AWS Cloud9 environment set up

---

## Exercise 4.1: Creating Your First Module
**Duration:** 20 minutes

### Step 1: Create Module Structure
```bash
mkdir terraform-lab4
cd terraform-lab4

# Set your username environment variable (replace YOUR_USERNAME with your actual username)
export TF_VAR_username="YOUR_USERNAME"

# Create module directory structure
mkdir -p modules/networking
mkdir -p modules/security  
mkdir -p modules/compute

# Create main configuration files
touch main.tf variables.tf outputs.tf terraform.tfvars
```

### Step 2: Build the Networking Module
Create the networking module:

**modules/networking/variables.tf:**
```hcl
variable "username" {
  description = "Unique username for resource naming and isolation"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}
```

**modules/networking/main.tf:**
```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-vpc"
    Username = var.username
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-igw"
    Username = var.username
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-public-${count.index + 1}"
    Type = "public"
    Username = var.username
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-private-${count.index + 1}"
    Type = "private"
    Username = var.username
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(var.private_subnet_cidrs)
  
  domain = "vpc"
  
  depends_on = [aws_internet_gateway.main]
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    Username = var.username
  })
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = length(var.private_subnet_cidrs)
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-nat-${count.index + 1}"
    Username = var.username
  })
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-public-rt"
    Username = var.username
  })
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
    Username = var.username
  })
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

**modules/networking/outputs.tf:**
```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}
```

### Step 3: Build the Security Module
**modules/security/variables.tf:**
```hcl
variable "username" {
  description = "Unique username for resource naming and isolation"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}
```

**modules/security/main.tf:**
```hcl
# Web Server Security Group
resource "aws_security_group" "web" {
  name_prefix = "${var.username}-${var.project_name}-${var.environment}-web-"
  description = "Security group for web servers (user: ${var.username})"
  vpc_id      = var.vpc_id
  
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
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-web-sg"
    Username = var.username
  })
}

# Application Security Group
resource "aws_security_group" "app" {
  name_prefix = "${var.username}-${var.project_name}-${var.environment}-app-"
  description = "Security group for application servers (user: ${var.username})"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "Application Port"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-app-sg"
    Username = var.username
  })
}

# Database Security Group
resource "aws_security_group" "db" {
  name_prefix = "${var.username}-${var.project_name}-${var.environment}-db-"
  description = "Security group for database (user: ${var.username})"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "MySQL/Aurora"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-db-sg"
    Username = var.username
  })
}
```

**modules/security/outputs.tf:**
```hcl
output "web_security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "app_security_group_id" {
  description = "ID of the app security group"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db.id
}
```

---

## Exercise 4.2: Using Modules
**Duration:** 15 minutes

### Step 1: Create Root Configuration
Create `variables.tf` first:

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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
```

Create `terraform.tfvars` (replace "user1" with your unique username):

```hcl
# IMPORTANT: Replace "user1" with your unique username
username = "user1"
instance_type = "t2.micro"
```

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
  
  # Note: Backend will be configured during terraform init
  # State file will be isolated per user
}

provider "aws" {
  region = "us-east-2"
}

# Local values for common configuration with username
locals {
  project_name = "modular-app"
  environment  = "dev"
  
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "DevTeam"
    Username    = var.username
  }
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  
  username     = var.username
  project_name = local.project_name
  environment  = local.environment
  
  vpc_cidr               = "10.0.0.0/16"
  availability_zones     = ["us-east-2a", "us-east-2b"]
  public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs   = ["10.0.10.0/24", "10.0.20.0/24"]
  
  tags = local.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"
  
  username     = var.username
  project_name = local.project_name
  environment  = local.environment
  vpc_id       = module.networking.vpc_id
  
  tags = local.common_tags
}
```


**outputs.tf:**
```hcl
output "vpc_info" {
  description = "VPC information"
  value = {
    vpc_id            = module.networking.vpc_id
    vpc_cidr          = module.networking.vpc_cidr_block
    public_subnets    = module.networking.public_subnet_ids
    private_subnets   = module.networking.private_subnet_ids
  }
}

output "security_groups" {
  description = "Security group IDs"
  value = {
    web_sg = module.security.web_security_group_id
    app_sg = module.security.app_security_group_id
    db_sg  = module.security.db_security_group_id
  }
}
```

### Step 2: Test Module Composition
```bash
# Initialize with user-specific state file
terraform init -backend-config="path=terraform-${TF_VAR_username}.tfstate"
terraform plan
terraform apply

# View outputs
terraform output
terraform output -json vpc_info
```

---

## Exercise 4.3: Compute Module and Complete Stack
**Duration:** 10 minutes

### Step 1: Create Compute Module
**modules/compute/variables.tf:**
```hcl
variable "username" {
  description = "Unique username for resource naming and isolation"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of private subnets"
  type        = list(string)
}

variable "web_security_group_id" {
  description = "ID of web security group"
  type        = string
}

variable "app_security_group_id" {
  description = "ID of app security group"
  type        = string
}

variable "db_security_group_id" {
  description = "ID of database security group"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}
```

**modules/compute/main.tf:**
```hcl
# Get latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Web servers in public subnets
resource "aws_instance" "web" {
  count = length(var.public_subnet_ids)
  
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[count.index]
  vpc_security_group_ids = [var.web_security_group_id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Web Server ${count.index + 1}</h1>" > /var/www/html/index.html
    echo "<p>Environment: ${var.environment}</p>" >> /var/www/html/index.html
  EOF
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-web-${count.index + 1}"
    Type = "web-server"
    Username = var.username
  })
}

# Application servers in private subnets
resource "aws_instance" "app" {
  count = length(var.private_subnet_ids)
  
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [var.app_security_group_id]
  
  tags = merge(var.tags, {
    Name = "${var.username}-${var.project_name}-${var.environment}-app-${count.index + 1}"
    Type = "app-server"
    Username = var.username
  })
}
```

**modules/compute/outputs.tf:**
```hcl
output "web_server_ids" {
  description = "IDs of web servers"
  value       = aws_instance.web[*].id
}

output "web_server_public_ips" {
  description = "Public IPs of web servers"
  value       = aws_instance.web[*].public_ip
}

output "app_server_ids" {
  description = "IDs of app servers"
  value       = aws_instance.app[*].id
}

output "app_server_private_ips" {
  description = "Private IPs of app servers"
  value       = aws_instance.app[*].private_ip
}
```

### Step 2: Add Compute Module to Main Configuration
Update **main.tf** to include the compute module:

```hcl
# Add this after the security module

# Compute Module
module "compute" {
  source = "./modules/compute"
  
  username              = var.username
  project_name           = local.project_name
  environment           = local.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  web_security_group_id = module.security.web_security_group_id
  app_security_group_id = module.security.app_security_group_id
  db_security_group_id  = module.security.db_security_group_id
  instance_type         = var.instance_type
  
  tags = local.common_tags
}
```

Update **outputs.tf** to include compute outputs:

```hcl
# Add to existing outputs

output "compute_info" {
  description = "Compute resource information"
  value = {
    web_servers = {
      ids        = module.compute.web_server_ids
      public_ips = module.compute.web_server_public_ips
    }
    app_servers = {
      ids         = module.compute.app_server_ids
      private_ips = module.compute.app_server_private_ips
    }
  }
}
```

### Step 3: Deploy Complete Stack
```bash
# Apply the complete stack
terraform apply

# View all outputs
terraform output

# Test web servers (use public IP from output)
curl http://$(terraform output -json compute_info | jq -r '.web_servers.public_ips[0]')
```

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Module Structure:**
   - Proper organization with variables, main, and outputs
   - Consistent naming and tagging patterns
   - Modular design principles

2. **Module Composition:**
   - Using modules together to build complex infrastructure
   - Passing outputs between modules as inputs
   - Managing dependencies between modules

3. **Module Benefits:**
   - Code reusability across projects and environments
   - Simplified testing and validation
   - Standardized infrastructure patterns
   - Team collaboration and knowledge sharing

### Best Practices Demonstrated

- Keep modules focused on a single responsibility
- Use descriptive variable names and documentation
- Provide comprehensive outputs for module consumers
- Use consistent tagging strategies
- Version your modules for stability
- **Multi-User Environment:**
  - Pass username variables through all modules
  - Maintain consistent naming patterns across modules
  - Include username in all resource tags
  - Ensure module reusability while maintaining isolation

### Module Testing Tips

```bash
# Test individual modules
cd modules/networking
terraform init
terraform plan -var="username=${TF_VAR_username}" -var="project_name=test" -var="environment=test"

# Use terraform validate for syntax checking
terraform validate
```

### Clean Up
```bash
# Destroy your username-prefixed resources
terraform destroy

# Verify your state file is cleaned up
ls -la terraform-*.tfstate*
```

---

## Next Steps
In Lab 5, you'll learn about:
- Remote state management
- Terraform Cloud integration
- Advanced state operations
- Team collaboration workflows

---

## Troubleshooting

### Common Issues
1. **Module not found:** Check source paths and module structure
2. **Variable not defined:** Ensure all required variables are passed to modules
3. **Circular dependencies:** Review module dependencies and outputs
4. **Resource conflicts:** Check for name conflicts between modules