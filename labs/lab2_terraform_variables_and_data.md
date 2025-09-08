# Lab 2: Variables and Data Sources (SIMPLIFIED)
**Duration:** 45 minutes  
**Difficulty:** Beginner  
**Day:** 1  
**Environment:** AWS Cloud9

---

## 🎯 **Simple Learning Objectives**
By the end of this lab, you will be able to:
- Use different variable types (string, number, boolean)
- Use data sources to find existing AWS resources
- Create an EC2 instance using variables and data sources
- Understand basic outputs

---

## 📋 **Prerequisites**
- Completion of Lab 1
- Understanding of basic Terraform workflow

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 📝 **Exercise 2.1: Understanding Variables (15 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab2
cd terraform-lab2
```

### Step 2: Create variables.tf
```hcl
# variables.tf - Define your variables

variable "username" {
  description = "Your unique username"
  type        = string
}

variable "instance_type" {
  description = "Size of the EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "instance_count" {
  description = "How many instances to create"
  type        = number
  default     = 1
}

variable "enable_monitoring" {
  description = "Turn on detailed monitoring"
  type        = bool
  default     = false
}
```

### Step 3: Create terraform.tfvars
```hcl
# terraform.tfvars - Your variable values

username = "user1"  # Replace with your username
instance_type = "t2.micro"
instance_count = 1
enable_monitoring = true
```

---

## 🔍 **Exercise 2.2: Using Data Sources (15 minutes)**

### Step 1: Create main.tf with data sources
```hcl
# main.tf - Configuration with data sources

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

# Data source: Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Data source: Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source: Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a simple security group
resource "aws_security_group" "web" {
  name        = "${var.username}-web-sg"
  description = "Allow web traffic"
  
  # Allow HTTP traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.username}-web-sg"
    Owner = var.username
  }
}

# Create EC2 instance(s)
resource "aws_instance" "web" {
  count = var.instance_count
  
  # Use the AMI from the data source
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  # Use the first subnet from data source
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.web.id]
  
  # Enable monitoring based on variable
  monitoring = var.enable_monitoring
  
  # Simple web server setup
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from ${var.username}!</h1>" > /var/www/html/index.html
    echo "<p>Instance: ${count.index + 1}</p>" >> /var/www/html/index.html
    echo "<p>Type: ${var.instance_type}</p>" >> /var/www/html/index.html
  EOF
  
  tags = {
    Name = "${var.username}-web-${count.index + 1}"
    Owner = var.username
    Type = "WebServer"
  }
}
```

---

## 📤 **Exercise 2.3: Understanding Outputs (15 minutes)**

### Step 1: Create outputs.tf
```hcl
# outputs.tf - Show important information

output "ami_id" {
  description = "ID of the AMI used"
  value       = data.aws_ami.amazon_linux.id
}

output "ami_name" {
  description = "Name of the AMI used"
  value       = data.aws_ami.amazon_linux.name
}

output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.web[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses"
  value       = aws_instance.web[*].public_ip
}

output "web_urls" {
  description = "URLs to access your web servers"
  value       = [for ip in aws_instance.web[*].public_ip : "http://${ip}"]
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web.id
}
```

---

## ⚙️ **Exercise 2.4: Deploy and Test (5 minutes)**

### Step 1: Deploy Your Infrastructure
```bash
# Initialize
terraform init

# Plan - see what will be created
terraform plan

# Apply - create the resources
terraform apply
```

### Step 2: View Your Outputs
```bash
# See all outputs
terraform output

# Get just the web URLs
terraform output web_urls
```

### Step 3: Test Your Web Server
```bash
# Get the URL from outputs and test it
curl $(terraform output -raw web_urls | grep -o 'http://[^"]*' | head -1)

# You should see your HTML page!
```

---

## 🧪 **Exercise 2.5: Experiment with Variables (5 minutes)**

### Try Different Values
Edit `terraform.tfvars` and try:

```hcl
# Change to create 2 instances
instance_count = 2

# Change to a larger instance
instance_type = "t2.small"

# Turn off monitoring
enable_monitoring = false
```

Then run:
```bash
terraform plan
terraform apply
```

See how the changes affect your infrastructure!

---

## 🎉 **Lab Summary**

### What You Accomplished:
✅ **Used 4 different variable types**: string, number, boolean, and their defaults  
✅ **Used 3 data sources**: AMI lookup, default VPC, and subnets  
✅ **Created 2 AWS resources**: Security group and EC2 instance(s)  
✅ **Generated 6 outputs**: AMI info, instance details, and web URLs  
✅ **Deployed a working web server** accessible from the internet  
✅ **Experimented with changes** using variables  

### Key Concepts Learned:
- **Variable Types**: String, number, boolean, and how to use defaults
- **Data Sources**: Query existing AWS resources instead of hardcoding
- **Count**: Create multiple similar resources using `count`
- **Outputs**: Display important information after deployment
- **References**: Use data source and resource attributes in other resources

### Files You Created:
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Variable values  
- `main.tf` - Your infrastructure configuration
- `outputs.tf` - Information to display after deployment

---

## 🔍 **Understanding What You Built**

### Data Sources Used:
1. **aws_ami**: Found the latest Amazon Linux 2 AMI automatically
2. **aws_vpc**: Found your default VPC (every AWS account has one)
3. **aws_subnets**: Found subnets in the default VPC

### Resources Created:
1. **Security Group**: Firewall rules allowing web traffic
2. **EC2 Instance**: Virtual server running a simple web page

### Variables Used:
1. **username** (string): Makes your resources unique
2. **instance_type** (string): Controls server size  
3. **instance_count** (number): Controls how many servers
4. **enable_monitoring** (boolean): Controls detailed monitoring

---

## 🧹 **Clean Up**

```bash
# Don't forget to clean up!
terraform destroy

# Type 'yes' when prompted
```

---

## ❓ **Troubleshooting**

### Problem: "No AMI found"
**Solution**: Make sure you're in us-east-2 region

### Problem: "Instance failed to start"
**Solution**: Wait a few minutes - EC2 takes time to boot

### Problem: "Can't access web page"
**Solution**: Wait 2-3 minutes for the web server to install and start

---

## 🎯 **Next Steps**

In Lab 3, you'll learn:
- How to create multiple related resources
- Resource dependencies (making sure things are created in the right order)
- Using `for_each` instead of `count`

**Great job! You've mastered variables and data sources! 🚀**