# Lab 3: Resource Dependencies and Lifecycle
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
- `user1-dependency-demo-vpc` (VPC)
- `user1-dependency-demo-igw` (Internet Gateway) 
- `user1-dependency-demo-dev-app` (instances)
- `terraform-user1.tfstate` (state file)

---

## Lab Objectives
By the end of this lab, you will be able to:
- Understand implicit and explicit resource dependencies
- Use count and for_each for multiple resources
- Implement resource lifecycle management
- Work with dynamic blocks and complex resource relationships

---

## Prerequisites
- Completion of Labs 1-2
- Understanding of Terraform variables and data sources
- AWS Cloud9 environment set up

---

## Exercise 3.1: Resource Dependencies
**Duration:** 15 minutes

### Step 1: Create Lab Environment
```bash
mkdir terraform-lab3
cd terraform-lab3

# Set your username environment variable (replace YOUR_USERNAME with your actual username)
export TF_VAR_username="YOUR_USERNAME"

touch main.tf variables.tf outputs.tf terraform.tfvars
```

### Step 2: Implicit Dependencies
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

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dependency-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}
```

Create `terraform.tfvars` (replace "user1" with your unique username):

```hcl
# IMPORTANT: Replace "user1" with your unique username
username = "user1"
project_name = "dependency-demo"
environment = "lab"
```

Create `main.tf` with implicit dependencies:

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

# Step 1: Create VPC (no dependencies) with username prefix
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.username}-${var.project_name}-vpc"
    Environment = var.environment
    Username = var.username
  }
}

# Step 2: Create Internet Gateway (depends on VPC) with username prefix
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # Implicit dependency
  
  tags = {
    Name = "${var.username}-${var.project_name}-igw"
    Environment = var.environment
    Username = var.username
  }
}

# Step 3: Create public subnet (depends on VPC) with username prefix
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id  # Implicit dependency
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.username}-${var.project_name}-public-subnet"
    Environment = var.environment
    Username = var.username
  }
}

# Step 4: Create route table (depends on VPC) with username prefix
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id  # Implicit dependency
  
  # Route to Internet Gateway (implicit dependency on IGW)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.username}-${var.project_name}-public-rt"
    Environment = var.environment
    Username = var.username
  }
}

# Step 5: Associate subnet with route table (depends on both)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id      # Implicit dependency
  route_table_id = aws_route_table.public.id  # Implicit dependency
}
```

### Step 3: Explicit Dependencies
Add explicit dependencies to `main.tf`:

```hcl
# Security group that should be created after networking is complete
resource "aws_security_group" "web" {
  name_prefix = "${var.username}-${var.project_name}-web-"
  description = "Security group for web servers (user: ${var.username})"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
  
  # Explicit dependency - wait for route table association
  depends_on = [aws_route_table_association.public]
  
  tags = {
    Name = "${var.username}-${var.project_name}-web-sg"
    Environment = var.environment
    Username = var.username
  }
}
```

### Step 4: Test Dependencies
```bash
# Initialize with user-specific state file
terraform init -backend-config="path=terraform-${TF_VAR_username}.tfstate"
terraform plan

# Notice the order of resource creation in the plan
# Apply and observe the creation order
terraform apply
```

---

## Exercise 3.2: Count and For_Each
**Duration:** 15 minutes

### Step 1: Using Count for Multiple Resources
Add to your `main.tf`:

```hcl
# Create multiple subnets using count
resource "aws_subnet" "private" {
  count = 2
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.username}-${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Type = "private"
    Username = var.username
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create NAT gateways for each private subnet
resource "aws_eip" "nat" {
  count = 2
  
  domain = "vpc"
  
  depends_on = [aws_internet_gateway.main]
  
  tags = {
    Name = "${var.username}-${var.project_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
    Username = var.username
  }
}

resource "aws_nat_gateway" "main" {
  count = 2
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public.id  # All NAT gateways in public subnet
  
  tags = {
    Name = "${var.username}-${var.project_name}-nat-gateway-${count.index + 1}"
    Environment = var.environment
    Username = var.username
  }
}
```

### Step 2: Using For_Each for Complex Resources
Add for_each resources:

```hcl
# Define environments as a local variable
locals {
  environments = {
    dev = {
      instance_type = "t2.micro"
      min_size     = 1
      max_size     = 2
    }
    staging = {
      instance_type = "t2.small"
      min_size     = 1
      max_size     = 3
    }
  }
  
  # Security group rules as a map
  security_rules = {
    http = {
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    }
    https = {
      port        = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access"
    }
    ssh = {
      port        = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "SSH access from VPC"
    }
  }
}

# Create security groups for different environments
resource "aws_security_group" "app" {
  for_each = local.environments
  
  name_prefix = "${var.username}-${var.project_name}-${each.key}-app-"
  description = "Security group for ${each.key} environment (user: ${var.username})"
  vpc_id      = aws_vpc.main.id
  
  dynamic "ingress" {
    for_each = local.security_rules
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
  }
  
  tags = {
    Name = "${var.username}-${var.project_name}-${each.key}-app-sg"
    Environment = each.key
    InstanceType = each.value.instance_type
    Username = var.username
  }
}
```

### Step 3: Reference For_Each Resources
Add instances that use the for_each security groups:

```hcl
# Get Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create instances for each environment
resource "aws_instance" "app" {
  for_each = local.environments
  
  ami           = data.aws_ami.amazon_linux.id
  instance_type = each.value.instance_type
  subnet_id     = aws_subnet.public.id
  
  vpc_security_group_ids = [aws_security_group.app[each.key].id]
  
  tags = {
    Name = "${var.username}-${var.project_name}-${each.key}-app"
    Environment = each.key
    Type = "application"
    Username = var.username
  }
}
```

---

## Exercise 3.3: Resource Lifecycle Management
**Duration:** 15 minutes

### Step 1: Lifecycle Rules
Add lifecycle management to your resources:

```hcl
# Add lifecycle management to instances
resource "aws_instance" "app" {
  for_each = local.environments
  
  ami           = data.aws_ami.amazon_linux.id
  instance_type = each.value.instance_type
  subnet_id     = aws_subnet.public.id
  
  vpc_security_group_ids = [aws_security_group.app[each.key].id]
  
  # Lifecycle management
  lifecycle {
    # Prevent accidental destruction of production-like environments
    prevent_destroy = false  # Set to true for production
    
    # Create new instance before destroying old one (for zero downtime)
    create_before_destroy = true
    
    # Ignore changes to AMI (allow updates outside Terraform)
    ignore_changes = [
      ami,
      tags["LastModified"]
    ]
  }
  
  tags = {
    Name = "${var.username}-${var.project_name}-${each.key}-app"
    Environment = each.key
    Type = "application"
    Username = var.username
    LastModified = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Database with strict lifecycle rules
resource "aws_db_subnet_group" "main" {
  name       = "${var.username}-${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  
  tags = {
    Name = "${var.username}-${var.project_name}-db-subnet-group"
    Environment = var.environment
    Username = var.username
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.username}-${var.project_name}-database"
  
  allocated_storage    = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  
  db_name  = "appdb"
  username = "admin"
  password = "temporarypassword123!"  # In real scenarios, use AWS Secrets Manager
  
  db_subnet_group_name = aws_db_subnet_group.main.name
  skip_final_snapshot  = true  # For lab purposes
  
  # Strict lifecycle for database
  lifecycle {
    prevent_destroy = true  # Prevent accidental deletion
    
    ignore_changes = [
      password,  # Password changes handled outside Terraform
    ]
  }
  
  tags = {
    Name = "${var.username}-${var.project_name}-database"
    Environment = var.environment
    Username = var.username
  }
}
```

### Step 2: Replace Triggered By
Add a resource that gets replaced when another changes:

```hcl
# Configuration that triggers replacements
resource "aws_s3_bucket" "config" {
  bucket = "${var.username}-${var.project_name}-config-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name = "${var.username}-${var.project_name}-config"
    Environment = var.environment
    Username = var.username
    Version = "1.0"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Instance that gets replaced when S3 bucket configuration changes
resource "aws_instance" "config_dependent" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  
  vpc_security_group_ids = [aws_security_group.web.id]
  
  # This instance will be replaced if the S3 bucket is replaced
  lifecycle {
    replace_triggered_by = [
      aws_s3_bucket.config
    ]
  }
  
  tags = {
    Name = "${var.username}-${var.project_name}-config-dependent"
    ConfigBucket = aws_s3_bucket.config.id
    Environment = var.environment
    Username = var.username
  }
}
```

### Step 3: Test Lifecycle Behavior
Update `outputs.tf`:

```hcl
output "vpc_info" {
  description = "VPC information"
  value = {
    vpc_id     = aws_vpc.main.id
    cidr_block = aws_vpc.main.cidr_block
  }
}

output "subnet_info" {
  description = "Subnet information"
  value = {
    public_subnet  = aws_subnet.public.id
    private_subnets = aws_subnet.private[*].id
  }
}

output "instance_info" {
  description = "Instance information by environment"
  value = {
    for env, instance in aws_instance.app :
    env => {
      id         = instance.id
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  }
}

output "database_info" {
  description = "Database connection information"
  value = {
    endpoint = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
  }
  sensitive = true
}
```

```bash
# Apply the configuration
terraform apply

# Try to destroy the database (should fail due to prevent_destroy)
terraform destroy -target=aws_db_instance.main

# Update the S3 bucket tags to trigger replacement
terraform apply -var="username=${TF_VAR_username}" -var="project_name=dependency-demo-v2"

# Observe what gets replaced
```

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Resource Dependencies:**
   - Implicit dependencies through resource references
   - Explicit dependencies using `depends_on`
   - Understanding Terraform's dependency graph

2. **Multiple Resources:**
   - `count` for simple repetition with index-based access
   - `for_each` for complex objects with key-based access
   - When to choose count vs for_each

3. **Lifecycle Management:**
   - `prevent_destroy` to protect critical resources
   - `create_before_destroy` for zero-downtime updates
   - `ignore_changes` for externally managed attributes
   - `replace_triggered_by` for cascading updates

4. **Dynamic Blocks:**
   - Creating repeated nested blocks
   - Using for_each within dynamic blocks
   - Complex resource configurations

### Best Practices Demonstrated

- Use explicit dependencies when creation order matters beyond references
- Choose for_each over count when you need to reference resources by key
- Implement lifecycle rules to prevent accidental destruction
- Use dynamic blocks for complex, repeated configurations
- **Multi-User Environment:**
  - Prefix all resource names with username for isolation
  - Use consistent naming patterns across all resources
  - Implement proper state file isolation
  - Include username in resource tags for identification

### Clean Up
```bash
# Remove prevent_destroy first
# Edit main.tf and set prevent_destroy = false for database
terraform apply

# Then destroy everything (your username-prefixed resources)
terraform destroy

# Verify your state file is cleaned up
ls -la terraform-*.tfstate*
```

---

## Next Steps
In Lab 4, you'll learn about:
- Creating and structuring Terraform modules
- Module composition and reusability
- Publishing and consuming modules
- Module versioning and best practices

---

## Troubleshooting

### Common Issues
1. **Circular dependencies:** Check for resource references that create loops
2. **Count/for_each conflicts:** Can't use both on the same resource
3. **Lifecycle conflicts:** prevent_destroy conflicts with destroy operations
4. **Dynamic block syntax:** Ensure proper for_each and content structure