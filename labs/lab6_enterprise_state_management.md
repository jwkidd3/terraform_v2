# Lab 6: Enterprise State Management Patterns
**Duration:** 45 minutes  
**Difficulty:** Advanced  
**Day:** 2  
**Environment:** AWS Cloud9

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. All resources will be prefixed with your username
4. State files will be isolated per user with encryption
5. KMS keys and resources will be user-specific

**Example:** If your username is "user1", your resources will be named:
- State key: `user1/enterprise/production/terraform.tfstate`
- KMS key alias: `alias/user1-terraform-state-key`
- Resources: `user1-` prefixed

---

## Lab Objectives
By the end of this lab, you will be able to:
- Implement advanced state management patterns for enterprise environments
- Configure state file encryption and secure variable management
- Design state isolation strategies for multi-team environments
- Implement cross-stack data sharing and dependencies
- Understand state management best practices for production workloads

---

## Prerequisites
- Completion of Labs 1-5 (especially Lab 5: Remote State Management)
- Understanding of Terraform state concepts
- AWS Cloud9 environment set up
- Basic knowledge of encryption and security concepts

---

## Exercise 6.1: Advanced State Encryption and Security
**Duration:** 15 minutes

### Step 1: Implement State File Encryption
```bash
# Create advanced state management project
mkdir terraform-lab6-enterprise-state
cd terraform-lab6-enterprise-state

# Set your username environment variable (replace YOUR_USERNAME with your actual username)
export TF_VAR_username="YOUR_USERNAME"

# Create encrypted S3 backend configuration
cat > backend.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  backend "s3" {
    bucket         = "terraform-state-${random_id.bucket_suffix.hex}"
    key            = "${var.username}/enterprise/production/terraform.tfstate"
    region         = "us-east-2"
    
    # Enable encryption at rest
    encrypt        = true
    kms_key_id     = "alias/${var.username}-terraform-state-key"
    
    # Enable state locking
    dynamodb_table = "terraform-state-lock-${random_id.bucket_suffix.hex}"
    
    # Enable versioning and logging
    versioning     = true
    
    # Workspace key prefix for environment isolation
    workspace_key_prefix = "environments"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
EOF

# Create KMS key for state encryption
cat > kms.tf << 'EOF'
# Random suffix for unique naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# KMS key for Terraform state encryption
resource "aws_kms_key" "terraform_state" {
  description = "KMS key for Terraform state file encryption"
  
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  
  # Key rotation
  enable_key_rotation = true
  
  # Key policy
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Terraform to use the key"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "terraform-state-encryption-key"
    Environment = "production"
    Purpose     = "state-file-encryption"
  }
}

# KMS key alias
resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state-key"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# Data source for current AWS identity
data "aws_caller_identity" "current" {}

# Encrypted S3 bucket for state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "terraform-state-${random_id.bucket_suffix.hex}"
  force_destroy = true
  
  tags = {
    Name        = "Terraform State Storage"
    Environment = "production"
    Purpose     = "state-management"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-state-lock-${random_id.bucket_suffix.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }
  
  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform_state.arn
  }
  
  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "production"
    Purpose     = "state-locking"
  }
}
EOF

# Initialize and create the state infrastructure
terraform init
terraform plan
terraform apply -auto-approve

# Output important values for next exercises
terraform output
```

### Step 2: Configure Secure Variable Management
```bash
# Create secure variables configuration
cat > secure-variables.tf << 'EOF'
# AWS Secrets Manager for sensitive variables
resource "aws_secretsmanager_secret" "terraform_vars" {
  name                    = "terraform/production/variables-${random_id.bucket_suffix.hex}"
  description             = "Secure storage for Terraform variables"
  recovery_window_in_days = 7
  
  # Encryption with custom KMS key
  kms_key_id = aws_kms_key.terraform_state.arn
  
  tags = {
    Name        = "Terraform Production Variables"
    Environment = "production"
    Purpose     = "secure-variables"
  }
}

# Store sample secure variables
resource "aws_secretsmanager_secret_version" "terraform_vars" {
  secret_id = aws_secretsmanager_secret.terraform_vars.id
  
  secret_string = jsonencode({
    db_password     = "super-secure-password-123!"
    api_key         = "ak-1234567890abcdef"
    ssl_private_key = "-----BEGIN PRIVATE KEY-----\nMIIEvQ...sample...key\n-----END PRIVATE KEY-----"
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM role for accessing secrets
resource "aws_iam_role" "terraform_secrets_access" {
  name = "terraform-secrets-access-${random_id.bucket_suffix.hex}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
      }
    ]
  })
  
  tags = {
    Name        = "Terraform Secrets Access Role"
    Environment = "production"
  }
}

# IAM policy for secrets access
resource "aws_iam_role_policy" "terraform_secrets_access" {
  name = "terraform-secrets-access-policy"
  role = aws_iam_role.terraform_secrets_access.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.terraform_vars.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.terraform_state.arn
      }
    ]
  })
}
EOF

# Apply the secure variables configuration
terraform apply -auto-approve
```

---

## Exercise 6.2: Multi-Environment State Isolation
**Duration:** 15 minutes

### Step 1: Implement Workspace-Based Environment Isolation
```bash
# Create workspace isolation examples
mkdir -p environments/{dev,staging,production}

# Development environment configuration
cat > environments/dev/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  backend "s3" {
    # State will be stored at: s3://bucket/environments/dev/terraform.tfstate
    workspace_key_prefix = "environments"
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

# Development-specific resources
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"  # Small instance for dev
  
  tags = {
    Name        = "web-server-${terraform.workspace}"
    Environment = terraform.workspace
    Purpose     = "development"
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

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

output "instance_id" {
  value = aws_instance.web.id
}

output "workspace_name" {
  value = terraform.workspace
}
EOF

# Production environment configuration
cat > environments/production/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  backend "s3" {
    # State will be stored at: s3://bucket/environments/production/terraform.tfstate
    workspace_key_prefix = "environments"
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

# Production-specific resources with redundancy
resource "aws_instance" "web" {
  count = 2  # Multiple instances for production
  
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.small"  # Larger instance for production
  
  tags = {
    Name        = "web-server-${terraform.workspace}-${count.index + 1}"
    Environment = terraform.workspace
    Purpose     = "production"
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

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

output "instance_ids" {
  value = aws_instance.web[*].id
}

output "workspace_name" {
  value = terraform.workspace
}
EOF

# Test workspace isolation
echo "=== Testing Development Environment ==="
cd environments/dev

# Initialize with backend configuration from parent directory
terraform init -backend-config="../../backend.tf"

# Create and switch to dev workspace
terraform workspace new dev 2>/dev/null || terraform workspace select dev
terraform plan
terraform apply -auto-approve

echo "=== Testing Production Environment ==="
cd ../production

# Initialize with backend configuration
terraform init -backend-config="../../backend.tf"

# Create and switch to production workspace
terraform workspace new production 2>/dev/null || terraform workspace select production
terraform plan
terraform apply -auto-approve

cd ../..
```

### Step 2: Verify State Isolation
```bash
# Create state inspection script
cat > inspect-state.sh << 'EOF'
#!/bin/bash

echo "=== State Isolation Validation ==="
echo

echo "Development Environment State:"
cd environments/dev
terraform workspace select dev
terraform show -json | jq '.values.root_module.resources[] | {type: .type, name: .name, values: {instance_type: .values.instance_type, tags: .values.tags}}'
echo

echo "Production Environment State:"
cd ../production
terraform workspace select production
terraform show -json | jq '.values.root_module.resources[] | {type: .type, name: .name, values: {instance_type: .values.instance_type, tags: .values.tags}}'
echo

echo "Backend State Storage Locations:"
aws s3 ls s3://$(terraform output -raw terraform_state_bucket 2>/dev/null || echo "terraform-state-bucket")/environments/ --recursive
cd ../..
EOF

chmod +x inspect-state.sh
./inspect-state.sh
```

---

## Exercise 6.3: Cross-Stack Data Sharing and Dependencies
**Duration:** 15 minutes

### Step 1: Implement Cross-Stack Data Sharing
```bash
# Create shared infrastructure stack
mkdir -p stacks/{shared,application,monitoring}

# Shared infrastructure (VPC, networking)
cat > stacks/shared/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  backend "s3" {
    key = "shared/infrastructure/terraform.tfstate"
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

# VPC and networking infrastructure
resource "aws_vpc" "shared" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "shared-vpc"
    Environment = "shared"
    Stack       = "infrastructure"
  }
}

resource "aws_subnet" "public" {
  count = 2
  
  vpc_id                  = aws_vpc.shared.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "shared-public-subnet-${count.index + 1}"
    Environment = "shared"
    Type        = "public"
  }
}

resource "aws_internet_gateway" "shared" {
  vpc_id = aws_vpc.shared.id
  
  tags = {
    Name        = "shared-igw"
    Environment = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.shared.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shared.id
  }
  
  tags = {
    Name        = "shared-public-rt"
    Environment = "shared"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Shared security group
resource "aws_security_group" "web" {
  name        = "shared-web-sg"
  description = "Shared security group for web applications"
  vpc_id      = aws_vpc.shared.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
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
    Name        = "shared-web-sg"
    Environment = "shared"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

# Outputs for cross-stack references
output "vpc_id" {
  description = "VPC ID for cross-stack reference"
  value       = aws_vpc.shared.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for cross-stack reference"
  value       = aws_subnet.public[*].id
}

output "web_security_group_id" {
  description = "Web security group ID for cross-stack reference"
  value       = aws_security_group.web.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.shared.cidr_block
}
EOF

# Application stack that depends on shared infrastructure
cat > stacks/application/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  backend "s3" {
    key = "application/web-app/terraform.tfstate"
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

# Reference shared infrastructure using remote state
data "terraform_remote_state" "shared" {
  backend = "s3"
  
  config = {
    bucket = var.terraform_state_bucket
    key    = "shared/infrastructure/terraform.tfstate"
    region = var.aws_region
  }
}

# Application instances using shared infrastructure
resource "aws_instance" "app" {
  count = var.instance_count
  
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.terraform_remote_state.shared.outputs.public_subnet_ids[count.index % length(data.terraform_remote_state.shared.outputs.public_subnet_ids)]
  vpc_security_group_ids = [data.terraform_remote_state.shared.outputs.web_security_group_id]
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Application Server ${count.index + 1}</h1>" > /var/www/html/index.html
    echo "<p>VPC ID: ${data.terraform_remote_state.shared.outputs.vpc_id}</p>" >> /var/www/html/index.html
  EOF
  )
  
  tags = {
    Name        = "app-server-${count.index + 1}"
    Environment = "application"
    Stack       = "web-app"
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

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "instance_count" {
  description = "Number of application instances"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "Instance type for application servers"
  type        = string
  default     = "t2.micro"
}

output "instance_ids" {
  description = "Application instance IDs"
  value       = aws_instance.app[*].id
}

output "instance_public_ips" {
  description = "Application instance public IPs"
  value       = aws_instance.app[*].public_ip
}

output "shared_vpc_reference" {
  description = "Reference to shared VPC"
  value = {
    vpc_id     = data.terraform_remote_state.shared.outputs.vpc_id
    vpc_cidr   = data.terraform_remote_state.shared.outputs.vpc_cidr_block
    subnet_ids = data.terraform_remote_state.shared.outputs.public_subnet_ids
  }
}
EOF

# Deploy shared infrastructure first
echo "=== Deploying Shared Infrastructure ==="
cd stacks/shared

terraform init -backend-config="../../backend.tf"
terraform plan
terraform apply -auto-approve

# Get the state bucket name for application stack
BUCKET_NAME=$(cd ../../ && terraform output -raw terraform_state_bucket)

cd ../application

echo "=== Deploying Application Stack ==="
terraform init -backend-config="../../backend.tf"
terraform plan -var="terraform_state_bucket=$BUCKET_NAME"
terraform apply -var="terraform_state_bucket=$BUCKET_NAME" -auto-approve

cd ../..
```

### Step 2: Validate Cross-Stack Dependencies
```bash
# Create validation script
cat > validate-dependencies.sh << 'EOF'
#!/bin/bash

echo "=== Cross-Stack Dependency Validation ==="
echo

echo "Shared Infrastructure Outputs:"
cd stacks/shared
terraform output -json | jq .
echo

echo "Application Stack Remote State References:"
cd ../application
terraform output -json | jq .shared_vpc_reference
echo

echo "Dependency Graph:"
echo "Shared Stack → Application Stack"
echo "VPC Resources → EC2 Instances"
echo "Security Groups → Instance Security"
echo

echo "Testing Application Endpoints:"
PUBLIC_IPS=$(terraform output -json instance_public_ips | jq -r '.[]')
for ip in $PUBLIC_IPS; do
    echo "Testing http://$ip"
    curl -s --max-time 5 "http://$ip" | head -n 3 || echo "  (Connection may still be establishing)"
done

cd ../..
EOF

chmod +x validate-dependencies.sh
./validate-dependencies.sh
```

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Advanced State Encryption:**
   - Implemented KMS-based state file encryption
   - Configured secure variable storage with AWS Secrets Manager
   - Set up proper IAM roles and policies for access control

2. **Multi-Environment State Isolation:**
   - Used Terraform workspaces for environment separation
   - Implemented proper naming conventions and tagging
   - Verified state isolation between environments

3. **Cross-Stack Data Sharing:**
   - Designed modular infrastructure with separate stacks
   - Implemented remote state data sources for dependencies
   - Created proper output/input interfaces between stacks

4. **Enterprise Patterns:**
   - Established secure backend configurations
   - Implemented state locking and versioning
   - Created reusable patterns for team collaboration

### Architecture Implemented

```
Enterprise State Management Architecture:
├── KMS Encryption (state files encrypted at rest)
├── S3 Backend (with versioning and locking)
├── DynamoDB (state locking mechanism)
├── Workspace Isolation
│   ├── dev environment
│   ├── staging environment
│   └── production environment
└── Cross-Stack References
    ├── Shared Infrastructure Stack
    ├── Application Stack
    └── Monitoring Stack (future)
```

### Clean Up Resources
```bash
# Clean up in reverse dependency order
cd stacks/application
terraform destroy -var="terraform_state_bucket=$(cd ../../ && terraform output -raw terraform_state_bucket)" -auto-approve

cd ../shared
terraform destroy -auto-approve

cd environments/production
terraform destroy -auto-approve

cd ../dev
terraform destroy -auto-approve

cd ../..
terraform destroy -auto-approve

echo "All resources cleaned up!"
```

### Best Practices Learned

1. **Always encrypt state files** in production environments
2. **Use workspace isolation** for different environments
3. **Implement proper cross-stack dependencies** with remote state
4. **Secure variable management** with dedicated secret stores
5. **Version control and backup** all state configurations

---

## Next Steps
In Lab 7, you'll learn about:
- Advanced Terraform patterns and structures  
- CI/CD pipeline implementation with GitHub Actions
- Automated testing and validation
- Policy as code implementation

---

## Troubleshooting

### Common Issues and Solutions

1. **KMS Key Permissions**
   ```bash
   # If KMS permissions fail, check IAM policies
   aws iam get-user
   aws kms describe-key --key-id alias/terraform-state-key
   ```

2. **State Lock Conflicts**
   ```bash
   # If state is locked, identify and release if needed
   terraform force-unlock <LOCK_ID>
   ```

3. **Cross-Stack Reference Errors**
   ```bash
   # Ensure shared stack is deployed first
   cd stacks/shared && terraform apply
   ```

4. **Workspace Issues**
   ```bash
   # List and manage workspaces
   terraform workspace list
   terraform workspace select <workspace_name>
   ```