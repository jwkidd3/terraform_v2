# Lab 10: Terraform Cloud Integration and Remote Execution
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Set up and configure Terraform Cloud for enterprise workflow management
- Migrate existing infrastructure to Terraform Cloud with remote execution
- Implement secure variable management and workspace configuration
- Configure automated runs with VCS integration and approval workflows
- Monitor infrastructure changes and collaborate effectively using Terraform Cloud

---

## 📋 **Prerequisites**
- Completion of Labs 1-8
- Terraform Cloud account (free tier sufficient)
- Understanding of remote state management from Lab 5
- GitHub account for VCS integration

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## ☁️ **Exercise 10.1: Terraform Cloud Organization Setup (15 minutes)**

### Step 1: Create Terraform Cloud Organization
1. Go to https://app.terraform.io/
2. Sign up or sign in to your account
3. Create a new organization: `${username}-terraform-training`
4. Note your organization name for later use

### Step 2: Create Lab Directory and Configuration
```bash
mkdir terraform-lab10
cd terraform-lab10
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
  
  cloud {
    organization = "user1-terraform-training"  # Replace with your org name
    
    workspaces {
      name = "user1-infrastructure-lab9"      # Replace with your username
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

variable "username" {
  description = "Your unique username"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "terraform-cloud"
}

locals {
  name_prefix = "${var.username}-${var.environment}"
  
  common_tags = {
    Owner           = var.username
    Environment     = var.environment
    ManagedBy       = "TerraformCloud"
    Workspace       = "infrastructure-lab9"
    Lab             = "9"
    DeploymentType  = "Remote"
    CreatedAt       = timestamp()
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

# VPC for cloud-managed infrastructure
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.100.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.100.1.0/24", "10.100.2.0/24"]
  public_subnets  = ["10.100.101.0/24", "10.100.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true  # Cost optimization for training
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Type = "CloudManagedVPC"
  })
}

# Security group for web servers
resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-web-"
  description = "Security group for Terraform Cloud managed web servers"
  vpc_id      = module.vpc.vpc_id

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
    cidr_blocks = ["10.100.0.0/16"]  # Only from VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
    Type = "ApplicationLoadBalancer"
  })
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
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

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# Target Group
resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

# ALB Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = local.common_tags
}

# Launch Template
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    username    = var.username
    environment = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-web-server"
      Type = "WebServer"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "${local.name_prefix}-asg"
  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 3
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

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

# CloudWatch Dashboard for monitoring
resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "${local.name_prefix}-dashboard"

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
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "ALB Performance Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.web.name],
            [".", "GroupInServiceInstances", ".", "."],
            [".", "GroupTotalInstances", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "Auto Scaling Group Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = local.common_tags
}

# S3 bucket for application logs and artifacts
resource "aws_s3_bucket" "app_artifacts" {
  bucket = "${local.name_prefix}-artifacts-${random_string.bucket_suffix.result}"

  tags = merge(local.common_tags, {
    Type = "ApplicationArtifacts"
  })
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

### Step 3: Create User Data Script
Create **user_data.sh:**

```bash
#!/bin/bash
yum update -y
yum install -y httpd awscli

systemctl start httpd
systemctl enable httpd

# Create dynamic content showing Terraform Cloud integration
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Terraform Cloud Managed Infrastructure</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background: linear-gradient(135deg, #623ce4 0%, #7c4dff 100%);
        }
        .container { 
            background: white; 
            padding: 30px; 
            border-radius: 10px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.2); 
        }
        .header { 
            color: #623ce4; 
            text-align: center; 
            margin-bottom: 30px; 
            border-bottom: 2px solid #7c4dff;
            padding-bottom: 20px;
        }
        .cloud-badge {
            background: #623ce4;
            color: white;
            padding: 10px 20px;
            border-radius: 25px;
            display: inline-block;
            margin: 10px 0;
            font-weight: bold;
        }
        .info-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
            gap: 20px; 
            margin: 30px 0; 
        }
        .info-card { 
            background: #f8f9fa; 
            padding: 20px; 
            border-radius: 8px; 
            border-left: 4px solid #623ce4; 
        }
        .feature { 
            background: #e3f2fd; 
            padding: 10px; 
            margin: 10px 0; 
            border-radius: 5px; 
        }
        .status { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌩️ Terraform Cloud Managed Infrastructure</h1>
            <div class="cloud-badge">Remote Execution Environment</div>
            <h2>Owner: ${username} | Environment: ${environment}</h2>
        </div>
        
        <div class="info-grid">
            <div class="info-card">
                <h3>📊 Instance Information</h3>
                <p><strong>Instance ID:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
                <p><strong>Instance Type:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-type'); ?></p>
                <p><strong>AZ:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone'); ?></p>
                <p><strong>Private IP:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4'); ?></p>
                <p><strong>Launch Time:</strong> $(date)</p>
            </div>
            
            <div class="info-card">
                <h3>☁️ Terraform Cloud Features</h3>
                <div class="feature">✅ Remote State Management</div>
                <div class="feature">✅ Remote Plan & Apply</div>
                <div class="feature">✅ VCS Integration</div>
                <div class="feature">✅ Workspace Management</div>
                <div class="feature">✅ Variable Sets</div>
                <div class="feature">✅ Policy as Code (Sentinel)</div>
                <div class="feature">✅ Cost Estimation</div>
                <div class="feature">✅ Team Collaboration</div>
            </div>
            
            <div class="info-card">
                <h3>🏗️ Infrastructure Components</h3>
                <p><strong>VPC:</strong> Custom VPC with public/private subnets</p>
                <p><strong>Load Balancer:</strong> Application Load Balancer</p>
                <p><strong>Auto Scaling:</strong> 1-3 instances based on demand</p>
                <p><strong>Security:</strong> Layered security groups</p>
                <p><strong>Monitoring:</strong> CloudWatch Dashboard</p>
                <p><strong>High Availability:</strong> Multi-AZ deployment</p>
            </div>
            
            <div class="info-card">
                <h3>🔄 Deployment Details</h3>
                <p><strong>Managed By:</strong> Terraform Cloud</p>
                <p><strong>Workspace:</strong> infrastructure-lab9</p>
                <p><strong>Execution:</strong> Remote (Cloud-based)</p>
                <p><strong>State Storage:</strong> Terraform Cloud</p>
                <p><strong>Collaboration:</strong> <span class="status">Team-enabled</span></p>
                <p><strong>Version Control:</strong> <span class="status">Git-integrated</span></p>
            </div>
        </div>
        
        <div style="text-align: center; margin-top: 30px; padding: 20px; background: #e8f5e8; border-radius: 8px;">
            <h3>🎉 Successfully Deployed via Terraform Cloud!</h3>
            <p>This infrastructure was deployed using Terraform Cloud's remote execution capabilities,
            demonstrating enterprise-grade infrastructure management with collaboration, security, and automation.</p>
        </div>
    </div>
</body>
</html>
EOF

# Set permissions
chown apache:apache /var/www/html/index.html
chmod 644 /var/www/html/index.html

# Restart Apache
systemctl restart httpd

echo "Terraform Cloud managed web server setup completed"
```

---

## 🔧 **Exercise 10.2: Workspace Configuration and Remote Execution (20 minutes)**

### Step 1: Create Terraform Cloud Workspace
1. In Terraform Cloud UI, go to your organization
2. Click "New workspace"
3. Choose "CLI-driven workflow"
4. Name: `${username}-infrastructure-lab9`
5. Description: "Lab 9 - Terraform Cloud Integration"
6. Click "Create workspace"

### Step 2: Configure Workspace Variables
In your Terraform Cloud workspace, add these environment variables:
- `AWS_ACCESS_KEY_ID` (sensitive) - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` (sensitive) - Your AWS secret key  
- `AWS_DEFAULT_REGION` - `us-east-2`

Add these Terraform variables:
- `username` - Your username (e.g., "user1")

### Step 3: Execute Remote Plans and Applies
```bash
# Authenticate with Terraform Cloud
terraform login

# Initialize with cloud backend
terraform init

# Create a plan (runs remotely in Terraform Cloud)
terraform plan

# Apply the changes (runs remotely in Terraform Cloud)
terraform apply

# Check outputs
terraform output
```

### Step 4: Monitor Remote Execution
1. Go to your Terraform Cloud workspace
2. Watch the run in progress
3. Review execution logs in real-time
4. Examine the plan details and resource changes
5. Approve the apply when prompted

---

## 🚀 **Exercise 10.3: Advanced Terraform Cloud Features (10 minutes)**

### Step 1: Create Outputs File
Create **outputs.tf:**

```hcl
output "application_url" {
  description = "URL to access the Terraform Cloud managed application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "infrastructure_summary" {
  description = "Summary of Terraform Cloud managed infrastructure"
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_cidr              = module.vpc.vpc_cidr_block
    public_subnets        = module.vpc.public_subnets
    private_subnets       = module.vpc.private_subnets
    alb_dns_name          = aws_lb.main.dns_name
    alb_zone_id           = aws_lb.main.zone_id
    auto_scaling_group    = aws_autoscaling_group.web.name
    s3_artifacts_bucket   = aws_s3_bucket.app_artifacts.id
    dashboard_url         = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=${aws_cloudwatch_dashboard.infrastructure.dashboard_name}"
  }
}

output "terraform_cloud_details" {
  description = "Terraform Cloud workspace and execution details"
  value = {
    execution_mode        = "remote"
    state_storage        = "terraform_cloud"
    workspace_management = "cloud_based"
    collaboration_enabled = true
    # cost_estimation not available in free tier
    policy_enforcement   = "available"
    remote_operations    = "enabled"
  }
}

output "deployment_info" {
  description = "Information about the current deployment"
  value = {
    deployed_by          = "terraform_cloud"
    environment          = var.environment
    managed_resources    = "vpc, alb, asg, security_groups, cloudwatch, s3"
    high_availability    = "multi_az"
    auto_scaling_enabled = true
    monitoring_enabled   = true
    remote_execution     = true
  }
}

output "workspace_features" {
  description = "Terraform Cloud workspace features demonstrated"
  value = {
    remote_state         = "✅ Centralized state storage"
    remote_execution     = "✅ Cloud-based plan/apply"
    variable_management  = "✅ Secure variable storage"
    workspace_isolation  = "✅ Isolated execution environment"
    run_history         = "✅ Complete audit trail"
    collaboration       = "✅ Team access and permissions"
    # cost_estimation     = "Available in paid tiers"
    policy_checks       = "✅ Governance and compliance"
  }
}
```

### Step 2: Test Terraform Cloud Features
1. **State Management**: View state versions in Terraform Cloud UI
2. **Run Details**: Review plan output and apply status
3. **Variable Management**: Update variables through the UI
4. **Run History**: Review previous runs and changes
5. **Collaboration**: Invite team members (if available)

### Step 3: Explore Advanced Workspace Settings
1. **General Settings**: 
   - Auto Apply: Configure automatic applies
   - Terraform Version: Set specific version
2. **VCS Settings**: 
   - Connect to Git repository (optional)
   - Configure automatic runs on commits
3. **Notifications**: 
   - Set up Slack/email notifications
   - Configure run status alerts

---

## 🔍 **Exercise 10.4: Troubleshooting and Best Practices (5 minutes)**

### Step 1: Common Terraform Cloud Issues
Test these scenarios:
```bash
# Trigger a plan with an intentional error
# Add invalid configuration to main.tf temporarily
terraform plan

# Review error handling in Terraform Cloud UI
# Fix the error and re-run
```

### Step 2: Best Practices Demonstrated
Review what you've implemented:
- ✅ **Variable Security**: Sensitive variables marked as sensitive
- ✅ **Resource Tagging**: Consistent tagging strategy
- ✅ **Remote State**: Centralized state management
- ✅ **Workspace Isolation**: Separate workspace for different purposes
- ✅ **Version Pinning**: Terraform and provider versions specified
- ✅ **Monitoring Integration**: CloudWatch dashboard for visibility

---

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ **Terraform Cloud Setup**: Created organization and configured remote execution workspace
- ✅ **Remote Infrastructure Management**: Deployed complete application stack via Terraform Cloud
- ✅ **Secure Variable Management**: Implemented proper credential and variable storage
- ✅ **Monitoring Integration**: Created CloudWatch dashboard for infrastructure visibility
- ✅ **Enterprise Workflow**: Established foundation for team collaboration and governance
- ✅ **Advanced Features**: Explored run history, state management, and workspace features

**Key Terraform Cloud Concepts:**
- **Remote Execution**: All Terraform operations run in Terraform Cloud, not locally
- **State Management**: Centralized, versioned state storage with automatic locking
- **Workspace Isolation**: Separate execution environments for different infrastructure
- **Variable Security**: Encrypted storage of sensitive variables and credentials
- **Collaboration Foundation**: Team-ready configuration with proper access controls

**Enterprise Features Demonstrated:**
- Cloud-based execution environment with consistent Terraform versions
- Automatic state versioning and backup
- Remote plan and apply execution with detailed logs
- Complete audit trail of all infrastructure modifications
- Secure credential management with encryption at rest
- Workspace-based organization for team collaboration

**Production-Ready Patterns:**
- Multi-AZ deployment for high availability
- Auto Scaling Groups with proper health checks
- Application Load Balancer for traffic distribution
- CloudWatch monitoring and dashboards
- S3 versioning and encryption
- Comprehensive resource tagging strategy

**Benefits Over Local Execution:**
- Consistent execution environment across team members
- Centralized state management eliminates state conflicts
- Automatic backups and version history
- Integrated security scanning and policy enforcement
- Detailed plan output showing resource changes
- Complete audit trail for compliance requirements

---

## 🧹 **Cleanup**
```bash
# Destroy infrastructure via Terraform Cloud (runs remotely)
terraform destroy

# Confirm destruction in Terraform Cloud UI
# Review the destroy plan before approving
```

This lab demonstrates the enterprise advantages of Terraform Cloud, providing centralized state management, remote execution, and the foundation for team collaboration while maintaining the same infrastructure-as-code principles you've learned throughout the course.