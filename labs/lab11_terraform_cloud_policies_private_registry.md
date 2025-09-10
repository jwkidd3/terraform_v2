# Lab 11: Terraform Registry and Module Sharing
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Explore the public Terraform Registry
- Create and structure your own Terraform modules
- Understand module versioning and publishing
- Use modules from the Terraform Registry in your configurations
- Share modules through version control

---

## 📋 **Prerequisites**
- Completion of Lab 10 (Terraform Cloud Workspaces)
- Understanding of Terraform modules from Lab 4
- GitHub account for module sharing
- Basic knowledge of module structure

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 📚 **Exercise 11.1: Exploring the Terraform Registry (15 minutes)**

### Step 1: Browse the Public Registry
1. Go to the **Terraform Registry**: https://registry.terraform.io
2. Search for popular modules:
   - **VPC**: terraform-aws-modules/vpc/aws
   - **Security Group**: terraform-aws-modules/security-group/aws
   - **S3 Bucket**: terraform-aws-modules/s3-bucket/aws

### Step 2: Understand Module Documentation
Pick the **VPC module** and explore:
1. **Usage examples** - How to use the module
2. **Inputs** - What variables it accepts
3. **Outputs** - What values it returns
4. **Resources** - What AWS resources it creates
5. **Versions** - Available module versions

### Step 3: Review Module Quality
Look for indicators of good modules:
- ✅ Clear documentation
- ✅ Usage examples
- ✅ Regular updates
- ✅ Good version history
- ✅ Community adoption (download count)

---

## 🔧 **Exercise 11.2: Create Your Own Module (20 minutes)**

### Step 1: Create Module Directory Structure
```bash
mkdir terraform-lab11
cd terraform-lab11

# Create a simple web server module
mkdir modules
mkdir modules/web-server
cd modules/web-server
```

### Step 2: Create Module Files
**modules/web-server/main.tf:**
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security group for web server
resource "aws_security_group" "web" {
  name_prefix = "${var.name}-web-"
  description = "Security group for web server"

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

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-web-sg"
  })
}

# Web server instances
resource "aws_instance" "web" {
  count = var.instance_count

  ami                    = data.aws_ami.amazon_linux.id
  instance_type         = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    server_name = "${var.name}-${count.index + 1}"
  }))

  tags = merge(var.tags, {
    Name = "${var.name}-web-${count.index + 1}"
  })
}
```

**modules/web-server/variables.tf:**
```hcl
variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5
    error_message = "Instance count must be between 1 and 5."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium"
    ], var.instance_type)
    error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

**modules/web-server/outputs.tf:**
```hcl
output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.web[*].id
}

output "public_ips" {
  description = "Public IP addresses of the instances"
  value       = aws_instance.web[*].public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web.id
}

output "instance_details" {
  description = "Complete instance information"
  value = {
    for i, instance in aws_instance.web :
    "web-${i + 1}" => {
      id        = instance.id
      public_ip = instance.public_ip
      az        = instance.availability_zone
    }
  }
}
```

**modules/web-server/user_data.sh:**
```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

cat > /var/www/html/index.html <<EOF
<html>
<head><title>${server_name}</title></head>
<body>
    <h1>Welcome to ${server_name}!</h1>
    <p>This server was created using a custom Terraform module.</p>
    <p>Server: ${server_name}</p>
    <p>Created: $(date)</p>
</body>
</html>
EOF
```

**modules/web-server/README.md:**
```markdown
# Web Server Module

This module creates simple web servers with Apache HTTP server.

## Usage

```hcl
module "web_servers" {
  source = "./modules/web-server"

  name           = "my-app"
  instance_count = 2
  instance_type  = "t3.micro"

  tags = {
    Environment = "development"
    Project     = "learning"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for resources | string | n/a | yes |
| instance_count | Number of instances | number | 1 | no |
| instance_type | EC2 instance type | string | "t3.micro" | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_ids | EC2 instance IDs |
| public_ips | Public IP addresses |
| security_group_id | Security group ID |
| instance_details | Complete instance info |
```

### Step 3: Use Your Module
Go back to the root directory and create a configuration that uses your module:

```bash
cd ../../  # Back to terraform-lab11 root
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
}

provider "aws" {
  region = "us-east-2"
}

# Use your custom module
module "web_servers" {
  source = "./modules/web-server"

  name           = "lab11-demo"
  instance_count = 2
  instance_type  = "t3.micro"

  tags = {
    Environment = "learning"
    Lab         = "11"
    Module      = "custom-web-server"
  }
}

# Also use a registry module for comparison
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "lab11-demo-bucket-${random_string.suffix.result}"

  tags = {
    Environment = "learning"
    Lab         = "11"
    Module      = "registry-s3"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
```

**outputs.tf:**
```hcl
output "web_server_details" {
  description = "Web server information"
  value       = module.web_servers.instance_details
}

output "web_server_ips" {
  description = "Web server public IPs"
  value       = module.web_servers.public_ips
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3_bucket.s3_bucket_id
}
```

---

## 🚀 **Exercise 11.3: Test and Share Your Module (10 minutes)**

### Step 1: Test Your Module
```bash
# Initialize and apply
terraform init
terraform plan
terraform apply

# Check outputs
terraform output
```

### Step 2: Test Your Web Servers
```bash
# Get the public IPs
WEB_IPS=$(terraform output -json web_server_ips | jq -r '.[]')

# Test each web server
for ip in $WEB_IPS; do
  echo "Testing http://$ip"
  curl -s "http://$ip" | grep -o '<title>.*</title>'
done
```

### Step 3: Prepare for Sharing (Optional)
If you want to share your module:

```bash
# Create a GitHub repository
git init
git add .
git commit -m "Initial web server module"

# Tag a version
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

**To use a shared module:**
```hcl
module "web_servers" {
  source = "git::https://github.com/YOUR_USERNAME/terraform-web-server-module.git?ref=v1.0.0"
  
  # module inputs...
}
```

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **Registry Exploration** - Browsed and understood public modules  
✅ **Module Creation** - Built a complete, reusable web server module  
✅ **Module Documentation** - Created proper README and variable descriptions  
✅ **Module Testing** - Deployed and tested your custom module  
✅ **Registry Comparison** - Used both custom and registry modules together  

### Key Concepts Learned
- **Module Structure**: Proper file organization and conventions
- **Module Interface**: Variables, outputs, and documentation
- **Module Reusability**: Creating flexible, configurable components
- **Registry Benefits**: Using proven, community-maintained modules
- **Version Control**: Tagging and sharing modules

### Module Best Practices
- **Clear Documentation**: README with usage examples
- **Variable Validation**: Input validation and constraints
- **Sensible Defaults**: Good default values for optional inputs
- **Comprehensive Outputs**: Useful return values
- **Proper Naming**: Descriptive resource and variable names

---

## 🧹 **Cleanup**
```bash
terraform destroy
```

---

## 🎓 **Next Steps**
In **Lab 12**, we'll implement **GitHub-triggered Terraform Cloud deployments** to complete your DevOps workflow.

**Key topics coming up:**
- VCS-driven workflows
- GitHub integration
- Automated deployments
- GitOps patterns