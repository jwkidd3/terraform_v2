# Lab 2 Complete Solution - Deployment Guide

## 🎯 Quick Start

### Prerequisites
```bash
# 1. Set your username environment variable
export TF_VAR_username="user1"  # Replace with your assigned username

# 2. Verify AWS credentials
aws sts get-caller-identity

# 3. Verify Terraform installation
terraform version
```

### Deployment Steps
```bash
# 1. Navigate to the solution directory
cd lab2_solution

# 2. Copy example variables (if needed)
cp terraform.tfvars.example terraform.tfvars

# 3. Edit terraform.tfvars with your username
# Make sure to change 'username = "user1"' to your actual username

# 4. Initialize Terraform
terraform init

# 5. Review the deployment plan
terraform plan

# 6. Deploy the infrastructure
terraform apply

# 7. View the outputs
terraform output
terraform output -json | jq .

# 8. Access the web application
terraform output instance_urls
```

### Clean Up
```bash
# Destroy all resources
terraform destroy

# Confirm destruction
# Type: yes
```

---

## 📊 What Gets Deployed

### Core Infrastructure
- **2 EC2 Instances** (t2.micro in dev environment)
- **1 Custom VPC** (10.0.0.0/16 CIDR)
- **2 Public Subnets** (across different AZs)  
- **1 Internet Gateway** (for internet access)
- **1 Security Group** (HTTP/HTTPS/SSH access)
- **1 S3 Bucket** (with sample JSON data)

### Networking Resources
- Route table and associations
- Public IP addresses for instances
- Security group rules for web traffic

### Additional Resources
- Random ID for unique naming
- Random pet name for fun identification  
- Random password (for demonstration)
- S3 bucket versioning and encryption
- Comprehensive resource tagging

---

## 🔧 Configuration Options

### Environment Variables
```bash
# Required
export TF_VAR_username="your_username"

# Optional overrides
export TF_VAR_environment="staging"
export TF_VAR_instance_count="3"  
export TF_VAR_enable_monitoring="false"
```

### Variable Customization
Edit `terraform.tfvars` to customize:

```hcl
# Change environment (affects instance type)
environment = "staging"  # Options: dev, staging, prod

# Adjust instance count (1-5 allowed)
instance_count = 3

# Toggle VPC creation
create_vpc = false  # Use default VPC instead

# Modify networking
vpc_cidr = "10.1.0.0/16"
subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
```

---

## 🌐 Accessing Your Deployment

### Web Application
```bash
# Get instance URLs
terraform output instance_urls

# Example output:
# [
#   "http://3.145.123.45",
#   "http://18.222.234.56"
# ]

# Access directly
curl http://YOUR_INSTANCE_IP
```

### System Information API
```bash
# Get system info as JSON
curl http://YOUR_INSTANCE_IP/info/system.json | jq .
```

### AWS Console
1. **EC2 Dashboard**: See your instances tagged with your username
2. **VPC Dashboard**: View your custom VPC and subnets  
3. **S3 Console**: Check your data bucket with sample JSON
4. **CloudWatch**: Monitor instance metrics (if monitoring enabled)

---

## 📝 Key Learning Demonstrations

### 1. Variable Types
The solution demonstrates all Terraform variable types:
- **String**: `username`, `environment`, `aws_region`
- **Number**: `instance_count`  
- **Boolean**: `enable_monitoring`, `create_vpc`
- **List**: `availability_zones`, `subnet_cidrs`
- **Map**: `instance_types`, `common_tags`
- **Object**: `database_config`

### 2. Variable Validation
Multiple validation rules are implemented:
```hcl
validation {
  condition     = var.instance_count >= 1 && var.instance_count <= 5
  error_message = "Instance count must be between 1 and 5."
}
```

### 3. Data Sources
Several AWS data sources are used:
- `aws_caller_identity` - Account information
- `aws_region` - Current region details  
- `aws_availability_zones` - Available AZs
- `aws_ami` - Latest Amazon Linux 2 AMI
- `aws_vpc`/`aws_subnets` - Default VPC info (when not creating custom)

### 4. Local Values
Complex computations using locals:
```hcl
locals {
  name_prefix = "${var.username}-${var.project_name}-${var.environment}"
  instance_type = lookup(var.instance_types, var.environment, "t2.micro")
  total_instances = var.instance_count * length(var.availability_zones)
}
```

### 5. Outputs
Comprehensive outputs including:
- Instance details and URLs
- AMI information
- VPC and networking details
- S3 bucket information  
- Random values generated
- Summary of all resources

### 6. Templates
User data script uses Terraform templating:
```hcl
user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
  instance_name = "${local.name_prefix}-${count.index + 1}"
  environment   = var.environment
  username      = var.username
  pet_name      = random_pet.server.id
}))
```

---

## 🔍 Testing Different Scenarios

### Scenario 1: Default VPC Deployment
```hcl
# In terraform.tfvars
create_vpc = false
```
Uses existing default VPC instead of creating custom one.

### Scenario 2: Production Environment
```hcl
# In terraform.tfvars
environment = "prod"
instance_count = 1
```
- Uses t3.small instances
- Creates Elastic IP for first instance
- Applies production-appropriate settings

### Scenario 3: Multiple Instances
```hcl
# In terraform.tfvars
instance_count = 4
```
Creates 4 instances distributed across availability zones.

### Scenario 4: Custom Networking
```hcl
# In terraform.tfvars
vpc_cidr = "172.16.0.0/16"
subnet_cidrs = [
  "172.16.1.0/24",
  "172.16.2.0/24", 
  "172.16.3.0/24"
]
```
Uses different IP ranges for VPC and subnets.

---

## 🚨 Troubleshooting

### Common Issues

#### 1. Username Not Set
```bash
Error: variable "username" must be set
```
**Solution**: `export TF_VAR_username="your_username"`

#### 2. Resource Already Exists
```bash
Error: resource already exists
```
**Solution**: Another user may be using the same username. Choose a different one.

#### 3. Invalid CIDR Block
```bash
Error: invalid CIDR format
```
**Solution**: Ensure VPC and subnet CIDRs are valid IPv4 CIDR blocks.

#### 4. Instance Limit Exceeded  
```bash
Error: You have requested more instances than allowed
```
**Solution**: Reduce `instance_count` or request limit increase from instructor.

#### 5. AMI Not Found
```bash
Error: No AMI found matching criteria
```
**Solution**: Check if you're in the correct region (us-east-2).

### Debug Commands
```bash
# Check current variables
terraform console
> var.username
> local.name_prefix

# Validate configuration
terraform validate

# Check what will be created
terraform plan -detailed-exitcode

# Force refresh of data sources
terraform refresh

# Show current state
terraform show

# List all resources
terraform state list
```

---

## 🎓 Learning Outcomes

After completing this solution, you will understand:

✅ **Variable Management**: All Terraform variable types and validation  
✅ **Data Sources**: Querying existing AWS resources dynamically  
✅ **Local Values**: Computing values from variables and data sources  
✅ **Resource Relationships**: Dependencies between AWS resources  
✅ **Template Functions**: Using templatefile() for dynamic content  
✅ **Output Management**: Exposing resource information effectively  
✅ **Resource Tagging**: Comprehensive tagging strategies  
✅ **Multi-user Isolation**: Username-based resource naming  
✅ **Error Handling**: Variable validation and error messages  
✅ **Best Practices**: Clean code organization and documentation

---

## 📚 Next Steps

1. **Experiment**: Try different variable combinations
2. **Extend**: Add more resources (RDS, CloudWatch, etc.)  
3. **Optimize**: Implement conditional resource creation
4. **Secure**: Add more security group rules and IAM roles
5. **Monitor**: Enable detailed CloudWatch monitoring
6. **Scale**: Test with different instance counts and types

This solution serves as a comprehensive reference for all concepts covered in Lab 2!