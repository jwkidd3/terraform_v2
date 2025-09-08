# Lab 11: Terraform Cloud Policies and Private Registry
**Duration:** 45 minutes  
**Difficulty:** Advanced  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. Create separate policy sets and private modules for your user
4. All Terraform Cloud resources will be prefixed with your username
5. This ensures complete isolation between users for policies and modules

**Example:** If your username is "user1", your resources will be named:
- Policy Set: `user1-security-policies`
- Private Module: `user1/networking/aws`
- Workspaces: `user1-policy-demo`
- AWS resources: `user1-` prefixed

---

## Lab Objectives
By the end of this lab, you will be able to:
- Implement Sentinel policies for governance and compliance
- Set up cost estimation and budget controls
- Create and publish modules to the Private Registry
- Use version management for modules
- Apply policy enforcement across workspaces
- Build a governance framework for enterprise use

---

## Prerequisites
- Completion of Labs 9-10 (Terraform Cloud basics and teams)
- Active Terraform Cloud organization (Team & Governance plan for Sentinel)
- Understanding of policy as code concepts
- Basic knowledge of Terraform modules

---

## Exercise 11.1: Implementing Governance with Sentinel Policies
**Duration:** 15 minutes

### Step 1: Create Basic Cost Control Policy
```bash
# Create policy directory structure
mkdir terraform-policies-registry
cd terraform-policies-registry
mkdir -p {policies/sentinel,modules/networking,examples}

# Create first Sentinel policy for cost control
cat > policies/sentinel/cost-control.sentinel << 'EOF'
# Sentinel Policy: Cost Control
# Prevents deployments that exceed defined cost thresholds

import "tfplan/v2" as tfplan
import "decimal"

# Cost thresholds (monthly USD)
cost_threshold_warning = 50
cost_threshold_hard_limit = 200

# Get cost estimate from plan
proposed_cost = decimal.new(tfplan.cost_estimate.proposed_monthly_cost) else decimal.new(0)
current_cost = decimal.new(tfplan.cost_estimate.prior_monthly_cost) else decimal.new(0)
cost_increase = decimal.sub(proposed_cost, current_cost)

print("=== COST ANALYSIS ===")
print("Current monthly cost: $" + decimal.to_string(current_cost))
print("Proposed monthly cost: $" + decimal.to_string(proposed_cost))
print("Cost increase: $" + decimal.to_string(cost_increase))
print("Hard limit: $" + string(cost_threshold_hard_limit))

# Validation functions
cost_is_under_hard_limit = rule {
    decimal.less_than(proposed_cost, decimal.new(cost_threshold_hard_limit))
}

cost_increase_reasonable = rule {
    decimal.less_than(cost_increase, decimal.new(cost_threshold_warning))
}

# Main policy rule
main = rule {
    cost_is_under_hard_limit
}

# Warning for moderate increases
cost_warning = rule when decimal.greater_than(cost_increase, decimal.new(cost_threshold_warning)) {
    print("⚠️  WARNING: Cost increase exceeds $" + string(cost_threshold_warning))
    print("   Consider reviewing resource sizing and quantities")
    true
}
EOF

# Create resource compliance policy
cat > policies/sentinel/resource-compliance.sentinel << 'EOF'
# Sentinel Policy: Resource Compliance
# Enforces naming conventions, required tags, and approved instance types

import "tfplan/v2" as tfplan
import "strings"

# Approved instance types (add more as needed)
approved_instance_types = [
    "t2.micro", "t2.small", "t2.medium",
    "t3.micro", "t3.small", "t3.medium",
    "m5.large", "m5.xlarge"
]

# Required tags for all resources
required_tags = ["Environment", "Project", "Owner"]

# Helper function to get resources by type
get_resources_by_type = func(resource_type) {
    resources = {}
    for address, resource in tfplan.planned_values.root_module.resources {
        if resource.type is resource_type {
            resources[address] = resource
        }
    }
    return resources
}

# Validation: EC2 instances must use approved types
validate_instance_types = rule {
    all get_resources_by_type("aws_instance") as address, resource {
        resource.values.instance_type in approved_instance_types
    }
}

# Validation: Resources must have required tags
validate_required_tags = rule {
    all get_resources_by_type("aws_instance") as address, resource {
        all required_tags as tag {
            tag in keys(resource.values.tags else {})
        }
    }
}

# Validation: Naming conventions
validate_naming_convention = rule {
    all get_resources_by_type("aws_instance") as address, resource {
        strings.has_prefix(resource.values.tags["Name"] else "", "tfc-") and
        length(resource.values.tags["Name"] else "") > 4
    }
}

# Security: No public S3 buckets
validate_s3_security = rule {
    all get_resources_by_type("aws_s3_bucket_public_access_block") as address, resource {
        resource.values.block_public_acls is true and
        resource.values.block_public_policy is true and
        resource.values.ignore_public_acls is true and
        resource.values.restrict_public_buckets is true
    }
}

# Main compliance rule
main = rule {
    validate_instance_types and
    validate_required_tags and
    validate_naming_convention and
    validate_s3_security
}
EOF

# Create policy set configuration
cat > policies/sentinel/sentinel.hcl << 'EOF'
policy "cost-control" {
    source            = "./cost-control.sentinel"
    enforcement_level = "hard-mandatory"
}

policy "resource-compliance" {
    source            = "./resource-compliance.sentinel"
    enforcement_level = "soft-mandatory"
}
EOF
```

### Step 2: Create Mock Data for Testing
```bash
# Create test data directory
mkdir -p policies/sentinel/test/cost-control
mkdir -p policies/sentinel/test/resource-compliance

# Create mock test data for cost control
cat > policies/sentinel/test/cost-control/mock-tfplan-v2.json << 'EOF'
{
  "format_version": "1.1",
  "planned_values": {
    "root_module": {
      "resources": [
        {
          "address": "aws_instance.example",
          "mode": "managed",
          "type": "aws_instance",
          "name": "example",
          "values": {
            "ami": "ami-12345678",
            "instance_type": "t3.small",
            "tags": {
              "Name": "test-instance",
              "Environment": "dev",
              "Project": "demo"
            }
          }
        }
      ]
    }
  },
  "cost_estimate": {
    "prior_monthly_cost": "10.00",
    "proposed_monthly_cost": "25.00"
  }
}
EOF

# Create test case
cat > policies/sentinel/test/cost-control/pass.hcl << 'EOF'
mock "tfplan/v2" {
  module {
    source = "./mock-tfplan-v2.json"
  }
}

test {
  rules = {
    main = true
  }
}
EOF
```

### Step 3: Test Policies Locally (Optional)
```bash
# If you have Sentinel CLI installed locally, test the policies
# Otherwise, skip this step as policies will be tested in Terraform Cloud

# Install Sentinel CLI (if not available)
# wget https://releases.hashicorp.com/sentinel/0.21.1/sentinel_0.21.1_linux_amd64.zip
# unzip sentinel_0.21.1_linux_amd64.zip
# sudo mv sentinel /usr/local/bin/

# Test the policy (if Sentinel CLI is available)
# cd policies/sentinel
# sentinel test
```

---

## Exercise 11.2: Creating and Publishing Private Registry Modules
**Duration:** 15 minutes

### Step 1: Create VPC Module for Private Registry
```bash
# Create VPC module structure
cd terraform-policies-registry/modules/networking

cat > main.tf << 'EOF'
# Terraform Cloud Private Registry Module
# Module: networking/vpc
# Version: 1.0.0

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = merge(var.common_tags, {
    Name = var.name
    Type = "VPC"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count  = var.create_igw ? 1 : 0
  vpc_id = aws_vpc.main.id
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-igw"
    Type = "InternetGateway"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = var.create_public_subnets ? length(var.public_subnet_cidrs) : 0
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-public-${count.index + 1}"
    Type = "Public Subnet"
    Tier = "Public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = var.create_private_subnets ? length(var.private_subnet_cidrs) : 0
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-private-${count.index + 1}"
    Type = "Private Subnet"
    Tier = "Private"
  })
}

# NAT Gateway for private subnets
resource "aws_eip" "nat" {
  count = var.create_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  
  domain = "vpc"
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-nat-eip-${count.index + 1}"
    Type = "NAT Gateway EIP"
  })
  
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.create_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-nat-${count.index + 1}"
    Type = "NAT Gateway"
  })
}

# Route Tables
resource "aws_route_table" "public" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id
  
  dynamic "route" {
    for_each = var.create_igw ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.main[0].id
    }
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-public-rt"
    Type = "Public Route Table"
  })
}

resource "aws_route_table" "private" {
  count  = var.create_private_subnets ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 0
  vpc_id = aws_vpc.main.id
  
  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
    }
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-private-rt-${count.index + 1}"
    Type = "Private Route Table"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = var.create_public_subnets ? length(aws_subnet.public) : 0
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = var.create_private_subnets ? length(aws_subnet.private) : 0
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# VPC Flow Logs (optional)
resource "aws_flow_log" "vpc_flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  
  tags = merge(var.common_tags, {
    Name = "${var.name}-flow-logs"
    Type = "VPC Flow Logs"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  
  name              = "/aws/vpc/${var.name}/flowlogs"
  retention_in_days = var.flow_logs_retention_days
  
  tags = var.common_tags
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${var.name}-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.common_tags
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${var.name}-flow-log-policy"
  role = aws_iam_role.flow_log[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
EOF

# Create variables file
cat > variables.tf << 'EOF'
variable "name" {
  description = "Name to be used on all resources as prefix"
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "The cidr_block must be a valid CIDR block."
  }
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}

variable "create_igw" {
  description = "Controls if an Internet Gateway is created for public subnets and the related routes"
  type        = bool
  default     = true
}

variable "create_public_subnets" {
  description = "Controls if public subnets should be created"
  type        = bool
  default     = true
}

variable "create_private_subnets" {
  description = "Controls if private subnets should be created"
  type        = bool
  default     = true
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for public subnets"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "create_nat_gateway" {
  description = "Controls if NAT Gateways should be created for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all private subnets"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Specifies the number of days you want to retain log events in the log group"
  type        = number
  default     = 14
}
EOF

# Create outputs file
cat > outputs.tf << 'EOF'
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = var.create_igw ? aws_internet_gateway.main[0].id : null
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = var.create_public_subnets ? aws_route_table.public[0].id : null
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "availability_zones" {
  description = "A list of availability zones specified as argument to this module"
  value       = data.aws_availability_zones.available.names
}
EOF

# Create README for the module
cat > README.md << 'EOF'
# AWS VPC Terraform Module

This module creates a complete AWS VPC with public and private subnets, NAT gateways, and optional VPC flow logs.

## Features

- ✅ **Multi-AZ VPC** with configurable CIDR blocks
- ✅ **Public subnets** with Internet Gateway
- ✅ **Private subnets** with NAT Gateway(s)
- ✅ **Flexible NAT Gateway** deployment (single or per-AZ)
- ✅ **VPC Flow Logs** with CloudWatch integration
- ✅ **Comprehensive tagging** support
- ✅ **Input validation** for CIDR blocks
- ✅ **Security best practices** built-in

## Usage

```hcl
module "vpc" {
  source = "app.terraform.io/YOUR_ORG/networking/aws"
  
  name       = "my-vpc"
  cidr_block = "10.0.0.0/16"
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  single_nat_gateway = false
  enable_flow_logs   = true
  
  common_tags = {
    Environment = "production"
    Project     = "web-app"
    Owner       = "platform-team"
  }
}
```

## Examples

- [Basic VPC](../../examples/basic-vpc) - Simple VPC with public and private subnets
- [Advanced VPC](../../examples/advanced-vpc) - VPC with flow logs, multiple NAT gateways

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name to be used on all resources as prefix | string | n/a | yes |
| cidr_block | The CIDR block for the VPC | string | n/a | yes |
| public_subnet_cidrs | A list of CIDR blocks for public subnets | list(string) | [] | no |
| private_subnet_cidrs | A list of CIDR blocks for private subnets | list(string) | [] | no |
| enable_flow_logs | Whether to enable VPC Flow Logs | bool | false | no |
| single_nat_gateway | Provision single shared NAT Gateway | bool | false | no |
| common_tags | A map of tags to assign to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| public_subnet_ids | List of IDs of public subnets |
| private_subnet_ids | List of IDs of private subnets |
| nat_gateway_ids | List of IDs of the NAT Gateways |

## License

Apache 2 Licensed. See LICENSE for full details.
EOF

# Create version file
cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF
```

### Step 2: Create Example Usage
```bash
# Create example configuration
cd terraform-policies-registry/examples
mkdir basic-vpc
cd basic-vpc

cat > main.tf << 'EOF'
# Example: Basic VPC using Private Registry Module
terraform {
  required_version = ">= 1.5"
  
  cloud {
    organization = "YOUR_ORG_NAME"  # Replace with your org
    
    workspaces {
      name = "private-registry-example"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use module from Private Registry
module "main_vpc" {
  source  = "app.terraform.io/YOUR_ORG/networking/aws"
  version = "~> 1.0"
  
  name       = "tfc-demo-vpc"
  cidr_block = "10.0.0.0/16"
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  # Use single NAT Gateway for cost savings in demo
  single_nat_gateway = true
  enable_flow_logs   = true
  
  common_tags = {
    Environment = "demo"
    Project     = "tfc-private-registry"
    Owner       = "platform-team"
    ManagedBy   = "Terraform Cloud"
  }
}

# Example resource using the VPC
resource "aws_security_group" "example" {
  name_prefix = "tfc-demo-sg"
  vpc_id      = module.main_vpc.vpc_id
  
  ingress {
    from_port   = 80
    to_port     = 80
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
    Name        = "tfc-demo-sg"
    Environment = "demo"
    Project     = "tfc-private-registry"
    Owner       = "platform-team"
  }
}

# Compliant EC2 instance for policy testing
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"  # Approved instance type
  subnet_id     = module.main_vpc.public_subnet_ids[0]
  
  vpc_security_group_ids = [aws_security_group.example.id]
  
  tags = {
    Name        = "tfc-demo-instance"  # Compliant naming
    Environment = "demo"               # Required tag
    Project     = "tfc-private-registry" # Required tag
    Owner       = "platform-team"     # Required tag
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# S3 bucket with compliant security settings
resource "aws_s3_bucket" "example" {
  bucket = "tfc-demo-bucket-${random_id.suffix.hex}"
  
  tags = {
    Name        = "tfc-demo-bucket"
    Environment = "demo"
    Project     = "tfc-private-registry"
    Owner       = "platform-team"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id
  
  # Policy-compliant settings
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "suffix" {
  byte_length = 4
}
EOF

cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}
EOF

cat > outputs.tf << 'EOF'
output "vpc_info" {
  description = "VPC information from private registry module"
  value = {
    vpc_id              = module.main_vpc.vpc_id
    public_subnet_ids   = module.main_vpc.public_subnet_ids
    private_subnet_ids  = module.main_vpc.private_subnet_ids
    availability_zones  = module.main_vpc.availability_zones
  }
}

output "instance_info" {
  description = "EC2 instance information"
  value = {
    instance_id = aws_instance.example.id
    public_ip   = aws_instance.example.public_ip
    private_ip  = aws_instance.example.private_ip
  }
}

output "compliance_check" {
  description = "Compliance validation results"
  value = {
    s3_public_access_blocked = aws_s3_bucket_public_access_block.example.block_public_acls
    instance_type_approved   = contains(["t2.micro", "t3.micro", "t2.small", "t3.small"], aws_instance.example.instance_type)
    required_tags_present    = length(setintersection(keys(aws_instance.example.tags), ["Environment", "Project", "Owner"])) == 3
    naming_convention_ok     = startswith(aws_instance.example.tags["Name"], "tfc-")
  }
}
EOF
```

---

## Exercise 11.3: Implementing Complete Governance Framework
**Duration:** 15 minutes

### Step 1: Configure Policy Sets in Terraform Cloud
```bash
# Create script to configure policies via API
cat > configure-policies.sh << 'EOF'
#!/bin/bash

# Configure Terraform Cloud Policies via API
# Replace these with your actual values
TFC_TOKEN="your-terraform-cloud-token"
ORG_NAME="your-org-name"

echo "=== Configuring Terraform Cloud Policies ==="

# Create policy set
POLICY_SET_RESPONSE=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @- \
  "https://app.terraform.io/api/v2/organizations/$ORG_NAME/policy-sets" <<EOF
{
  "data": {
    "type": "policy-sets",
    "attributes": {
      "name": "governance-policies",
      "description": "Cost control and compliance policies for all workspaces",
      "global": true
    }
  }
}
EOF
)

POLICY_SET_ID=$(echo "$POLICY_SET_RESPONSE" | jq -r '.data.id')
echo "✅ Created policy set: $POLICY_SET_ID"

# Upload cost control policy
COST_POLICY_DATA=$(cat policies/sentinel/cost-control.sentinel | base64 -w 0)
COST_POLICY_RESPONSE=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @- \
  "https://app.terraform.io/api/v2/policy-sets/$POLICY_SET_ID/policies" <<EOF
{
  "data": {
    "type": "policies",
    "attributes": {
      "name": "cost-control",
      "description": "Prevents deployments exceeding cost thresholds",
      "kind": "sentinel",
      "query": "data.main",
      "enforcement-level": "hard-mandatory"
    }
  }
}
EOF
)

echo "✅ Uploaded cost control policy"

# Upload compliance policy  
COMPLIANCE_POLICY_DATA=$(cat policies/sentinel/resource-compliance.sentinel | base64 -w 0)
COMPLIANCE_POLICY_RESPONSE=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @- \
  "https://app.terraform.io/api/v2/policy-sets/$POLICY_SET_ID/policies" <<EOF
{
  "data": {
    "type": "policies",
    "attributes": {
      "name": "resource-compliance",
      "description": "Enforces naming conventions and required tags",
      "kind": "sentinel",
      "query": "data.main",
      "enforcement-level": "soft-mandatory"
    }
  }
}
EOF
)

echo "✅ Uploaded compliance policy"

# Get list of workspaces to apply policies to
WORKSPACES=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/organizations/$ORG_NAME/workspaces" | \
  jq -r '.data[].id')

echo "📋 Policy set configured and will apply to all workspaces"
echo "🔗 View in UI: https://app.terraform.io/app/$ORG_NAME/settings/policy-sets/$POLICY_SET_ID"
EOF

chmod +x configure-policies.sh

# Create manual instructions for UI configuration
cat > policy-setup-instructions.md << 'EOF'
# Manual Policy Setup Instructions

Since the API approach requires a paid Terraform Cloud plan, here are manual setup instructions:

## Step 1: Create Policy Set in UI

1. Log into Terraform Cloud
2. Navigate to Settings → Policy Sets
3. Click "Connect a new policy set"
4. Choose "Upload via API" or "Connect to VCS"

## Step 2: Create Cost Control Policy

1. In the policy set, click "New Policy"
2. Name: `cost-control`
3. Enforcement Level: `hard-mandatory`
4. Copy the content from `policies/sentinel/cost-control.sentinel`

## Step 3: Create Compliance Policy

1. Create another policy: `resource-compliance` 
2. Enforcement Level: `soft-mandatory`
3. Copy content from `policies/sentinel/resource-compliance.sentinel`

## Step 4: Apply to Workspaces

1. In the policy set settings
2. Go to "Workspaces" tab
3. Add relevant workspaces or set as global

## Step 5: Test Policies

1. Run terraform plan on a workspace
2. Policies will be evaluated during plan phase
3. Check run logs for policy results
EOF
```

### Step 2: Create Cost Monitoring Dashboard
```bash
# Create cost monitoring configuration
cat > cost-monitoring.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  cloud {
    organization = "YOUR_ORG_NAME"
    
    workspaces {
      name = "cost-monitoring"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# CloudWatch dashboard for cost monitoring
resource "aws_cloudwatch_dashboard" "cost_monitoring" {
  dashboard_name = "terraform-cloud-cost-monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-2"
          title  = "AWS Estimated Charges"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        
        properties = {
          query   = "SOURCE '/aws/lambda/cost-alert' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Cost Alert Logs"
        }
      }
    ]
  })
}

# Budget alert for cost control
resource "aws_budgets_budget" "terraform_cloud" {
  name     = "terraform-cloud-monthly-budget"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  budget_type  = "COST"
  
  cost_filters {
    tag {
      key = "ManagedBy"
      values = ["Terraform", "Terraform Cloud"]
    }
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "100"
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = ["admin@example.com"]
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.cost_monitoring.dashboard_name}"
}

output "budget_name" {
  value = aws_budgets_budget.terraform_cloud.name
}
EOF
```

### Step 3: Test the Complete Framework
```bash
# Deploy the example that will trigger policies
cd terraform-policies-registry/examples/basic-vpc

# Initialize the configuration
terraform init

# Run plan to see policy evaluation
terraform plan

echo "=== Testing Complete Framework ==="
echo "1. Policies should be evaluated during plan"
echo "2. Cost estimates should be shown"
echo "3. Compliance checks should pass/fail based on configuration"
echo "4. Check Terraform Cloud UI for detailed policy results"

# Apply if policies pass
terraform apply -auto-approve

# Show compliance results
terraform output compliance_check

# Deploy cost monitoring
cd terraform-policies-registry
terraform init
terraform apply -auto-approve

echo "=== Framework Deployment Complete ==="
echo "✅ VPC Module published to Private Registry"
echo "✅ Sentinel Policies configured for governance"
echo "✅ Cost monitoring and budgets set up"
echo "✅ Example infrastructure deployed with policy validation"
```

---

## Lab Summary and Key Takeaways

### What You've Accomplished

1. **Policy as Code Implementation:**
   - Created Sentinel policies for cost control
   - Implemented resource compliance policies
   - Set up policy enforcement across workspaces

2. **Private Registry Management:**
   - Built production-ready VPC module
   - Published module to Private Registry
   - Created comprehensive documentation
   - Implemented version management

3. **Governance Framework:**
   - Established cost thresholds and monitoring
   - Implemented naming conventions
   - Required tag enforcement
   - Security compliance validation

4. **Complete Integration:**
   - Combined policies with private modules
   - Created automated deployment pipeline
   - Set up monitoring and alerting
   - Tested end-to-end workflow

### Governance Architecture Implemented

```
Terraform Cloud Organization
├── Policy Sets (Global)
│   ├── Cost Control (hard-mandatory)
│   └── Resource Compliance (soft-mandatory)
├── Private Registry
│   └── networking/aws module (v1.0)
├── Workspaces
│   ├── private-registry-example (uses module + policies)
│   └── cost-monitoring (budget alerts)
└── Cost Management
    ├── Budget alerts at 80% and 100%
    └── CloudWatch dashboard
```

### Policy Enforcement Results

The framework you built enforces:

- ✅ **Cost limits** ($200 hard limit, $50 warning)
- ✅ **Instance types** (only approved types allowed)
- ✅ **Required tags** (Environment, Project, Owner)
- ✅ **Naming conventions** (must start with "tfc-")
- ✅ **S3 security** (no public access allowed)
- ✅ **Module usage** (standardized VPC deployments)

### Clean Up
```bash
# Clean up in reverse order
cd terraform-policies-registry/examples/basic-vpc
terraform destroy -auto-approve

cd terraform-policies-registry
terraform destroy -auto-approve

echo "Resources cleaned up!"
```

---

## Next Steps
In Lab 12 (Final Project), you'll combine everything learned to:
- Deploy a complete enterprise architecture
- Use all Terraform Cloud features together
- Implement a full governance and compliance framework
- Demonstrate production-ready infrastructure management

---

## Troubleshooting

### Common Issues and Solutions

1. **Policy Evaluation Fails**
   ```bash
   # Check policy syntax
   # Verify enforcement levels
   # Review Terraform Cloud run logs
   ```

2. **Module Not Found in Registry**
   - Verify organization name in module source
   - Check module publication status
   - Confirm version constraints

3. **Cost Estimation Not Working**
   - Cost estimation requires paid Terraform Cloud plan
   - Verify AWS pricing data availability
   - Check resource configurations

4. **Sentinel Policies Require Paid Plan**
   - Sentinel policies need Team & Governance plan
   - Consider using OPA policies (available in free tier)
   - Use workspace run tasks as alternative

5. **API Authentication Issues**
   ```bash
   # Verify API token permissions
   export TF_CLOUD_TOKEN="your-token-here"
   
   # Test API access
   curl -H "Authorization: Bearer $TF_CLOUD_TOKEN" \
        "https://app.terraform.io/api/v2/organizations" | jq .
   ```