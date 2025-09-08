# Lab 8: Advanced Networking with VPC
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. All resources will be prefixed with your username
4. Network resources (VPC, subnets, gateways) will be user-specific
5. This ensures complete network isolation between users

**Example:** If your username is "user1", your resources will be named:
- `user1-advanced-vpc-main`
- `user1-advanced-vpc-public-subnet-1`
- `user1-advanced-vpc-nat-gateway-1`
- State file: `terraform-user1.tfstate`

---

## Lab Objectives
By the end of this lab, you will be able to:
- Design and implement complex VPC architectures
- Configure multi-tier networking with public and private subnets
- Set up NAT Gateways and Internet Gateways
- Implement Network ACLs and routing tables
- Create VPC peering connections

---

## Prerequisites
- Completion of Labs 1-7
- Understanding of AWS networking concepts
- AWS Cloud9 environment set up

---

## Exercise 8.1: Multi-Tier VPC Architecture
**Duration:** 20 minutes

### Step 1: Create Lab Environment
```bash
mkdir terraform-lab8
cd terraform-lab8

touch main.tf variables.tf outputs.tf locals.tf
```

### Step 2: Define Advanced Networking Variables
**variables.tf:**
```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "advanced-networking"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "advanced-networking"
    ManagedBy = "Terraform"
  }
}
```

### Step 3: Create Advanced Locals for Network Calculations
**locals.tf:**
```hcl
locals {
  # Calculate subnet CIDRs for different tiers
  public_subnet_cidrs = [
    for i in range(length(var.availability_zones)) :
    cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]
  
  private_subnet_cidrs = [
    for i in range(length(var.availability_zones)) :
    cidrsubnet(var.vpc_cidr, 8, i + 10)
  ]
  
  database_subnet_cidrs = [
    for i in range(length(var.availability_zones)) :
    cidrsubnet(var.vpc_cidr, 8, i + 20)
  ]
  
  # Resource naming
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags
  tags = merge(var.common_tags, {
    Environment = var.environment
  })
}
```

### Step 4: Implement Advanced VPC Configuration
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
}

provider "aws" {
  region = "us-east-2"
  
  default_tags {
    tags = local.tags
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
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
    Tier = "public"
    AZ   = var.availability_zones[count.index]
  }
}

# Private Subnets (Application Tier)
resource "aws_subnet" "private" {
  count = length(var.availability_zones)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Tier = "private"
    AZ   = var.availability_zones[count.index]
  }
}

# Database Subnets
resource "aws_subnet" "database" {
  count = length(var.availability_zones)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "${local.name_prefix}-database-${count.index + 1}"
    Tier = "database"
    AZ   = var.availability_zones[count.index]
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0
  
  domain = "vpc"
  
  depends_on = [aws_internet_gateway.main]
  
  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
    AZ   = var.availability_zones[count.index]
  }
}
```

---

## Exercise 8.2: Advanced Routing and Network ACLs
**Duration:** 15 minutes

### Step 1: Create Route Tables
Add to **main.tf:**

```hcl
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ)
resource "aws_route_table" "private" {
  count = length(var.availability_zones)
  
  vpc_id = aws_vpc.main.id
  
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[count.index].id
    }
  }
  
  tags = {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
    Tier = "private"
    AZ   = var.availability_zones[count.index]
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database Route Table
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${local.name_prefix}-database-rt"
    Tier = "database"
  }
}

# Database Route Table Associations
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)
  
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
```

### Step 2: Implement Network ACLs
Add to **main.tf:**

```hcl
# Public Network ACL
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id
  
  # Allow inbound HTTP
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  
  # Allow inbound HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  
  # Allow inbound SSH from VPC
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 22
    to_port    = 22
  }
  
  # Allow return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 900
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  
  # Allow all outbound
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  tags = {
    Name = "${local.name_prefix}-public-nacl"
    Tier = "public"
  }
}

# Private Network ACL
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id
  
  # Allow inbound from VPC
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }
  
  # Allow return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 900
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  
  # Allow all outbound
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  tags = {
    Name = "${local.name_prefix}-private-nacl"
    Tier = "private"
  }
}

# Database Network ACL
resource "aws_network_acl" "database" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.database[*].id
  
  # Allow MySQL/Aurora from private subnets
  dynamic "ingress" {
    for_each = local.private_subnet_cidrs
    content {
      protocol   = "tcp"
      rule_no    = 100 + ingress.key
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 3306
      to_port    = 3306
    }
  }
  
  # Allow PostgreSQL from private subnets
  dynamic "ingress" {
    for_each = local.private_subnet_cidrs
    content {
      protocol   = "tcp"
      rule_no    = 200 + ingress.key
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 5432
      to_port    = 5432
    }
  }
  
  # Allow return traffic
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  
  tags = {
    Name = "${local.name_prefix}-database-nacl"
    Tier = "database"
  }
}
```

---

## Exercise 8.3: VPC Endpoints and Enhanced Security
**Duration:** 10 minutes

### Step 1: Create VPC Endpoints
Add to **main.tf:**

```hcl
# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.database.id]
  )
  
  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.dynamodb"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )
  
  tags = {
    Name = "${local.name_prefix}-dynamodb-endpoint"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name_prefix}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  }
}

# EC2 Interface Endpoint
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-2.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
  
  tags = {
    Name = "${local.name_prefix}-ec2-endpoint"
  }
}

# Systems Manager Interface Endpoints
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-2.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
  
  tags = {
    Name = "${local.name_prefix}-ssm-endpoint"
  }
}
```

### Step 2: Create Outputs
**outputs.tf:**
```hcl
output "vpc_info" {
  description = "VPC information"
  value = {
    vpc_id     = aws_vpc.main.id
    vpc_cidr   = aws_vpc.main.cidr_block
    vpc_arn    = aws_vpc.main.arn
  }
}

output "subnet_info" {
  description = "Subnet information"
  value = {
    public_subnets = {
      ids   = aws_subnet.public[*].id
      cidrs = aws_subnet.public[*].cidr_block
      azs   = aws_subnet.public[*].availability_zone
    }
    private_subnets = {
      ids   = aws_subnet.private[*].id
      cidrs = aws_subnet.private[*].cidr_block
      azs   = aws_subnet.private[*].availability_zone
    }
    database_subnets = {
      ids   = aws_subnet.database[*].id
      cidrs = aws_subnet.database[*].cidr_block
      azs   = aws_subnet.database[*].availability_zone
    }
  }
}

output "gateway_info" {
  description = "Gateway information"
  value = {
    internet_gateway_id = aws_internet_gateway.main.id
    nat_gateway_ids     = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
    nat_gateway_ips     = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
  }
}

output "vpc_endpoints" {
  description = "VPC endpoint information"
  value = {
    s3_endpoint       = aws_vpc_endpoint.s3.id
    dynamodb_endpoint = aws_vpc_endpoint.dynamodb.id
    ec2_endpoint      = aws_vpc_endpoint.ec2.id
    ssm_endpoint      = aws_vpc_endpoint.ssm.id
  }
}

output "route_table_info" {
  description = "Route table information"
  value = {
    public_route_table_id    = aws_route_table.public.id
    private_route_table_ids  = aws_route_table.private[*].id
    database_route_table_id  = aws_route_table.database.id
  }
}
```

### Step 3: Deploy and Test
```bash
# Initialize and deploy
terraform init
terraform plan
terraform apply

# View outputs
terraform output
terraform output -json subnet_info

# Test VPC endpoints
aws s3 ls --region us-east-2 --endpoint-url https://s3.us-east-2.amazonaws.com
```

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Multi-Tier VPC Architecture:**
   - Public, private, and database subnet tiers
   - Proper subnet CIDR allocation and planning
   - Cross-AZ redundancy and high availability

2. **Advanced Routing:**
   - Multiple route tables for different tiers
   - NAT Gateway configuration for private subnets
   - Route table associations and dependencies

3. **Network Security:**
   - Network ACLs for subnet-level security
   - Security groups for instance-level security
   - Layered security approach

4. **VPC Endpoints:**
   - Gateway endpoints for S3 and DynamoDB
   - Interface endpoints for AWS services
   - Cost optimization through private connectivity

### Network Architecture Implemented

```
Internet Gateway
       |
   Public Subnets (Web Tier)
       |
   NAT Gateways
       |
   Private Subnets (App Tier)
       |
   Database Subnets (DB Tier)
```

### Security Best Practices

- **Defense in Depth:** Multiple layers of security
- **Least Privilege:** Restrictive Network ACLs
- **Network Segmentation:** Separate tiers with different access patterns
- **Private Connectivity:** VPC endpoints for AWS services

### Clean Up
```bash
terraform destroy
```

---

## Next Steps
In Lab 9, you'll learn about:
- Auto Scaling Groups and Load Balancers
- Application deployment patterns
- Health checks and monitoring
- Blue-green deployment strategies

---

## Troubleshooting

### Common Issues
1. **CIDR Conflicts:** Ensure subnet CIDRs don't overlap
2. **Route Table Errors:** Verify route table associations
3. **Network ACL Blocks:** Check rule numbers and precedence
4. **VPC Endpoint Access:** Verify security group rules for interface endpoints