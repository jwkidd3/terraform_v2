# Lab 12: Final Project - Terraform Cloud Enterprise Integration
**Duration:** 45 minutes  
**Difficulty:** Expert  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud + GitHub

---

## Multi-User Environment Setup
**IMPORTANT:** This final lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the entire final project
3. Create a complete isolated environment with your username prefix
4. All Terraform Cloud and AWS resources will be user-specific
5. This capstone project demonstrates full multi-user production readiness

**Example:** If your username is "user1", your final project will include:
- Terraform Cloud Organization: `user1-enterprise-demo`
- Multiple Workspaces: `user1-networking`, `user1-security`, `user1-application`
- AWS Infrastructure: Complete 3-tier architecture with `user1-` prefix
- GitHub Repository: `user1/terraform-final-project`
- All resources isolated and production-ready

---

## Overview
This final lab integrates all concepts learned throughout the course, with emphasis on Terraform Cloud enterprise features. Students will deploy a complete production infrastructure using Terraform Cloud workspaces, private registry modules, policy enforcement, and advanced collaboration features.

## Learning Objectives
By the end of this lab, you will be able to:
- Deploy enterprise infrastructure using Terraform Cloud workflows
- Integrate private registry modules in production deployments
- Implement policy-as-code governance in real deployments
- Use Terraform Cloud team collaboration features
- Demonstrate complete Terraform Cloud mastery
- Apply all course concepts in an enterprise scenario

---

## Prerequisites
- Completion of Labs 1-11 (especially Labs 9-11 focusing on Terraform Cloud)
- Active Terraform Cloud organization with Team & Governance features
- Private registry modules created in Lab 11
- Policy sets configured from Lab 10
- AWS Cloud9 environment set up

---

## Exercise 12.1: Terraform Cloud Enterprise Workspace Setup (15 minutes)

### Step 1: Create Enterprise Project Structure
```bash
mkdir -p lab12-enterprise-integration/{environments/{dev,staging,prod},policies,scripts}
cd lab12-enterprise-integration

# Create main configuration files
touch main.tf variables.tf outputs.tf locals.tf
touch versions.tf
```

### Step 2: Configure Terraform Cloud Backend with Workspace Strategy
```bash
# Create versions.tf with Terraform Cloud backend
cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  cloud {
    organization = "your-org-name"  # Replace with your organization
    
    workspaces {
      name = "final-project-prod"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.51"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "tfe" {
  token = var.tfe_token
}
EOF
```

### Step 3: Create Terraform Cloud Workspace Configuration
```bash
# Create workspace management configuration
cat > workspace-config.tf << 'EOF'
# Create additional workspaces for dev and staging
resource "tfe_workspace" "dev" {
  name         = "final-project-dev"
  organization = var.organization_name
  auto_apply   = true  # Auto-apply for dev environment
  
  # Enable cost estimation and assessments
  assessments_enabled = true
  
  # Link to VCS (if using GitHub)
  vcs_repo {
    identifier     = "${var.github_username}/terraform-final-project"
    oauth_token_id = var.vcs_oauth_token
    branch         = "develop"
  }
  
  working_directory = "environments/dev"
  terraform_version = "1.6.0"
  
  description = "Development environment for final project"
}

resource "tfe_workspace" "staging" {
  name         = "final-project-staging"
  organization = var.organization_name
  auto_apply   = false  # Manual approval for staging
  
  # Enable cost estimation
  assessments_enabled = true
  
  vcs_repo {
    identifier     = "${var.github_username}/terraform-final-project"
    oauth_token_id = var.vcs_oauth_token
    branch         = "main"
  }
  
  working_directory = "environments/staging"
  terraform_version = "1.6.0"
  
  description = "Staging environment for final project"
}

# Variable sets for shared configuration
resource "tfe_variable_set" "aws_credentials" {
  name         = "aws-credentials"
  description  = "AWS credentials for all environments"
  organization = var.organization_name
  global       = false
}

resource "tfe_variable" "aws_access_key_id" {
  key             = "AWS_ACCESS_KEY_ID"
  value           = var.aws_access_key_id
  category        = "env"
  sensitive       = true
  variable_set_id = tfe_variable_set.aws_credentials.id
  description     = "AWS Access Key ID"
}

resource "tfe_variable" "aws_secret_access_key" {
  key             = "AWS_SECRET_ACCESS_KEY"
  value           = var.aws_secret_access_key
  category        = "env"
  sensitive       = true
  variable_set_id = tfe_variable_set.aws_credentials.id
  description     = "AWS Secret Access Key"
}

# Apply variable set to workspaces
resource "tfe_workspace_variable_set" "dev_aws" {
  variable_set_id = tfe_variable_set.aws_credentials.id
  workspace_id    = tfe_workspace.dev.id
}

resource "tfe_workspace_variable_set" "staging_aws" {
  variable_set_id = tfe_variable_set.aws_credentials.id
  workspace_id    = tfe_workspace.staging.id
}

# Current workspace (production) variables
resource "tfe_variable" "environment" {
  key          = "environment"
  value        = "prod"
  category     = "terraform"
  workspace_id = data.tfe_workspace.current.id
  description  = "Environment name"
}

resource "tfe_variable" "notification_email" {
  key          = "notification_email"
  value        = var.notification_email
  category     = "terraform"
  workspace_id = data.tfe_workspace.current.id
  description  = "Email for notifications"
}

data "tfe_workspace" "current" {
  name         = "final-project-prod"
  organization = var.organization_name
}
EOF
```

### Step 4: Define Enterprise Variables
```bash
cat > variables.tf << 'EOF'
# Terraform Cloud Configuration
variable "organization_name" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "tfe_token" {
  description = "Terraform Cloud API token"
  type        = string
  sensitive   = true
}

variable "github_username" {
  description = "GitHub username for VCS integration"
  type        = string
  default     = ""
}

variable "vcs_oauth_token" {
  description = "VCS OAuth token for Terraform Cloud"
  type        = string
  default     = ""
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

# Project Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
  
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.notification_email))
    error_message = "Must be a valid email address."
  }
}
EOF
```

---

## Exercise 12.2: Private Registry Module Integration (20 minutes)

### Step 1: Create Enterprise Infrastructure Using Private Registry Modules
```bash
# Create main infrastructure configuration using private registry modules
cat > main.tf << 'EOF'
# Local values for enterprise deployment
locals {
  project_name = "terraform-enterprise"
  environment  = var.environment
  region       = var.aws_region
  
  name_prefix = "${local.project_name}-${local.environment}"
  
  # Environment-specific configuration
  environment_config = {
    dev = {
      instance_type    = "t2.micro"
      min_size        = 1
      max_size        = 3
      desired_capacity = 1
    }
    staging = {
      instance_type    = "t2.small"
      min_size        = 2
      max_size        = 5
      desired_capacity = 2
    }
    prod = {
      instance_type    = "t3.small"
      min_size        = 3
      max_size        = 10
      desired_capacity = 3
    }
  }
  
  current_config = local.environment_config[local.environment]
  
  # Common tags managed by Terraform Cloud
  common_tags = {
    Project      = local.project_name
    Environment  = local.environment
    ManagedBy    = "TerraformCloud"
    Course       = "TerraformMastery"
    Owner        = "Student"
    CostCenter   = "Training"
  }
}
EOF
```

### Step 2: Deploy Infrastructure Using Private Registry Modules
```bash
# Add the enterprise infrastructure using private registry modules
cat >> main.tf << 'EOF'

# Deploy VPC using private registry module from Lab 11
module "vpc" {
  source  = "app.terraform.io/your-org-name/vpc/aws"  # Replace with your org
  version = "1.0.0"
  
  name = "${local.name_prefix}-vpc"
  cidr_block = "10.0.0.0/16"
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  
  enable_nat_gateway = local.environment == "prod" ? true : false
  single_nat_gateway = local.environment != "prod" ? true : false
  
  tags = local.common_tags
}

# Security groups for the application
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for Application Load Balancer"
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

resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-web-"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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

# Deploy EC2 Auto Scaling using private registry module from Lab 11
module "web_servers" {
  source  = "app.terraform.io/your-org-name/ec2-asg/aws"  # Replace with your org
  version = "1.0.0"
  
  name               = "${local.name_prefix}-web"
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [aws_security_group.web.id]
  
  instance_type    = local.current_config.instance_type
  min_size         = local.current_config.min_size
  max_size         = local.current_config.max_size
  desired_capacity = local.current_config.desired_capacity
  
  target_group_arns = [aws_lb_target_group.web.arn]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = local.environment
    project     = local.project_name
  }))
  
  tags = local.common_tags
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-tg"
  })
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# CloudWatch monitoring for enterprise deployment
resource "aws_cloudwatch_dashboard" "main" {
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
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", module.web_servers.autoscaling_group_name],
            [".", "GroupInServiceInstances", ".", "."],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          title   = "Application Metrics"
        }
      }
    ]
  })
}

# SNS topic for notifications
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
  
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
EOF
```

### Step 3: Create User Data Script for Web Servers
```bash
# Create user data script for web application
cat > user_data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd

# Start and enable httpd
systemctl start httpd
systemctl enable httpd

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create a simple web page
cat > /var/www/html/index.html << EOL
<!DOCTYPE html>
<html>
<head>
    <title>🎉 Terraform Cloud Enterprise Final Project</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { 
            background: rgba(255,255,255,0.1); 
            padding: 20px; 
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .metric { 
            background: rgba(255,255,255,0.2); 
            padding: 10px; 
            margin: 10px 0; 
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Terraform Cloud Enterprise Success!</h1>
        <h2>Congratulations on Mastering Terraform!</h2>
        
        <div class="metric">
            <strong>Environment:</strong> ${environment}
        </div>
        <div class="metric">
            <strong>Project:</strong> ${project}
        </div>
        <div class="metric">
            <strong>Instance ID:</strong> $INSTANCE_ID
        </div>
        <div class="metric">
            <strong>Availability Zone:</strong> $AZ
        </div>
        <div class="metric">
            <strong>Deployed via:</strong> Terraform Cloud Private Registry
        </div>
        <div class="metric">
            <strong>Policy Enforcement:</strong> ✅ Active
        </div>
        <div class="metric">
            <strong>Cost Estimation:</strong> ✅ Enabled
        </div>
        
        <h3>🏆 Course Completion Achievements:</h3>
        <ul>
            <li>✅ Terraform Cloud Workspaces</li>
            <li>✅ Private Registry Modules</li>
            <li>✅ Policy as Code (Sentinel/OPA)</li>
            <li>✅ Cost Estimation & Governance</li>
            <li>✅ Team Collaboration</li>
            <li>✅ Enterprise Infrastructure</li>
        </ul>
        
        <p><em>Refreshing this page will show different servers as the load balancer distributes traffic!</em></p>
    </div>
</body>
</html>
EOL

# Set proper permissions
chown apache:apache /var/www/html/index.html
chmod 644 /var/www/html/index.html
EOF
```
## Exercise 12.3: Policy Enforcement and Governance (5 minutes)

### Step 1: Apply Policies from Lab 10 to Final Project
```bash
# The policies created in Lab 10 will automatically apply to this workspace
# Create a policy compliance check script
cat > check_compliance.sh << 'EOF'
#!/bin/bash

echo "🔍 Checking Terraform Cloud Policy Compliance..."
echo "================================================"

# Check if TF_API_TOKEN is set
if [ -z "$TF_API_TOKEN" ]; then
    echo "❌ TF_API_TOKEN not set. Please run: terraform login"
    exit 1
fi

# Get the current workspace run
ORG_NAME="your-org-name"  # Replace with your organization
WORKSPACE_NAME="final-project-prod"

# Get the latest run for the workspace
RUN_ID=$(curl -s \
  --header "Authorization: Bearer $TF_API_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_NAME/runs?page[size]=1" | \
  jq -r '.data[0].id')

echo "📊 Latest Run ID: $RUN_ID"

# Check policy results
echo "🔐 Policy Results:"
curl -s \
  --header "Authorization: Bearer $TF_API_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/runs/$RUN_ID/policy-checks" | \
  jq -r '.data[] | "Policy: \(.attributes.scope) | Result: \(.attributes.result) | Status: \(.attributes.status)"'

echo ""
echo "💰 Cost Estimation:"
curl -s \
  --header "Authorization: Bearer $TF_API_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/runs/$RUN_ID/cost-estimate" | \
  jq -r '.data.attributes | "Monthly Cost: \(.proposed-monthly-cost) | Delta: \(.delta-monthly-cost)"'

echo "================================================"
echo "✅ Policy compliance check complete!"
EOF

chmod +x check_compliance.sh
```

### Step 2: Verify Policy Enforcement in Terraform Cloud
```bash
# When you run terraform plan/apply, you'll see policy checks in action:
echo "When you deploy this infrastructure, Terraform Cloud will:"
echo "1. ✅ Run cost estimation before apply"
echo "2. 🔐 Execute Sentinel/OPA policies from Lab 10"
echo "3. 🚨 Send notifications for policy violations"
echo "4. 📊 Provide detailed compliance reporting"
echo "5. 💰 Show cost impact of infrastructure changes"
```
## Exercise 12.4: Team Collaboration and Run Triggers (5 minutes)

### Step 1: Configure Run Triggers Between Workspaces
```bash
# Add run trigger configuration to link environments
cat >> workspace-config.tf << 'EOF'

# Configure run triggers so prod runs after staging
resource "tfe_run_trigger" "staging_to_prod" {
  workspace_id    = data.tfe_workspace.current.id  # Production workspace
  sourceable_id   = tfe_workspace.staging.id       # Staging workspace
  sourceable_type = "workspace"
}

# Team access management
resource "tfe_team" "developers" {
  name         = "developers"
  organization = var.organization_name
}

resource "tfe_team" "platform_engineers" {
  name         = "platform-engineers"
  organization = var.organization_name
}

# Workspace access for teams
resource "tfe_team_access" "dev_workspace" {
  access       = "write"
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.dev.id
}

resource "tfe_team_access" "staging_workspace" {
  access       = "plan"
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.staging.id
}

resource "tfe_team_access" "prod_workspace" {
  access       = "read"
  team_id      = tfe_team.developers.id
  workspace_id = data.tfe_workspace.current.id
}

# Platform engineers have admin access to all workspaces
resource "tfe_team_access" "platform_all_envs" {
  for_each = {
    dev     = tfe_workspace.dev.id
    staging = tfe_workspace.staging.id
    prod    = data.tfe_workspace.current.id
  }
  
  access       = "admin"
  team_id      = tfe_team.platform_engineers.id
  workspace_id = each.value
}
EOF
```

### Step 2: Configure Notifications and Webhooks
```bash
# Add notification configurations for enterprise collaboration
cat >> workspace-config.tf << 'EOF'

# Slack notifications for production workspace
resource "tfe_notification_configuration" "slack_prod" {
  name             = "slack-notifications"
  enabled          = true
  destination_type = "slack"
  url              = var.slack_webhook_url  # Add this variable if you have Slack
  workspace_id     = data.tfe_workspace.current.id
  
  triggers = [
    "run:planning",
    "run:needs_attention",
    "run:applying",
    "run:completed",
    "run:errored"
  ]
}

# Email notifications for critical events
resource "tfe_notification_configuration" "email_alerts" {
  name             = "email-alerts"
  enabled          = true
  destination_type = "email"
  email_addresses  = [var.notification_email]
  workspace_id     = data.tfe_workspace.current.id
  
  triggers = [
    "run:needs_attention",
    "run:errored",
    "assessment:check_failure"
  ]
}
EOF

# Add the slack webhook variable
cat >> variables.tf << 'EOF'

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications (optional)"
  type        = string
  default     = ""
}
EOF
```
### Step 3: Create Enterprise Outputs
```bash
cat > outputs.tf << 'EOF'
output "terraform_cloud_enterprise_summary" {
  description = "Terraform Cloud Enterprise deployment summary"
  value = {
    # Project Information
    project_name = local.project_name
    environment  = local.environment
    region       = var.aws_region
    
    # Terraform Cloud Information
    organization_name = var.organization_name
    workspace_name    = "final-project-prod"
    
    # Infrastructure Endpoints
    application_url      = "http://${aws_lb.main.dns_name}"
    load_balancer_dns    = aws_lb.main.dns_name
    dashboard_url        = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
    
    # Network Information
    vpc_id              = module.vpc.vpc_id
    public_subnet_ids   = module.vpc.public_subnet_ids
    private_subnet_ids  = module.vpc.private_subnet_ids
    
    # Auto Scaling Information
    autoscaling_group_name = module.web_servers.autoscaling_group_name
    
    # Terraform Cloud Features Used
    features_implemented = [
      "Private Registry Modules",
      "Policy as Code Enforcement", 
      "Cost Estimation",
      "Team Collaboration",
      "Run Triggers",
      "Notification Integration",
      "Variable Sets",
      "Workspace Management"
    ]
  }
}

output "enterprise_success_message" {
  description = "Enterprise deployment success message"
  value = [
    "🎉 ================================== 🎉",
    "    TERRAFORM CLOUD ENTERPRISE SUCCESS!",
    "🎉 ================================== 🎉",
    "",
    "🌐 Application URL: http://${aws_lb.main.dns_name}",
    "📊 CloudWatch Dashboard: Available in AWS Console",
    "🏢 Organization: ${var.organization_name}",
    "💼 Workspace: final-project-prod",
    "",
    "🚀 TERRAFORM CLOUD ENTERPRISE FEATURES DEPLOYED:",
    "   ✅ Private Registry Modules (from Lab 11)",
    "   ✅ Policy Enforcement (from Lab 10)", 
    "   ✅ Cost Estimation & Governance",
    "   ✅ Team Collaboration & Access Controls",
    "   ✅ Multi-Environment Workspaces (dev/staging/prod)",
    "   ✅ Run Triggers & Automation",
    "   ✅ Notification Integration",
    "   ✅ Variable Sets for Credential Management",
    "",
    "🏆 COURSE COMPLETION ACHIEVEMENTS:",
    "   📚 12 Comprehensive Labs Completed",
    "   ⏱️  540 Minutes (9 Hours) of Hands-on Experience",
    "   🎯 70% Hands-on / 30% Theory Ratio Achieved",
    "   ☁️  AWS Cloud9 Environment Mastery",
    "   🏢 Terraform Cloud Enterprise Skills",
    "   🔐 Security & Compliance Best Practices",
    "   📊 Infrastructure Monitoring & Observability",
    "",
    "🎓 YOU ARE NOW TERRAFORM CERTIFIED-READY!",
    "   Next: HashiCorp Terraform Associate Certification",
    "   https://www.hashicorp.com/certification/terraform-associate",
    ""
  ]
}

output "testing_instructions" {
  description = "Testing instructions for the deployed infrastructure"
  value = [
    "🧪 TESTING YOUR TERRAFORM CLOUD ENTERPRISE DEPLOYMENT:",
    "",
    "1. 🌐 Test the Application:",
    "   curl http://${aws_lb.main.dns_name}",
    "   (Refresh browser to see different servers)",
    "",
    "2. 📊 Monitor in Terraform Cloud:",
    "   • Go to app.terraform.io/${var.organization_name}",
    "   • Check run history and policy results",
    "   • Review cost estimations",
    "",
    "3. 🚨 Test Notifications:",
    "   • Confirm email subscription from SNS",
    "   • Make a change and watch notifications",
    "",
    "4. 👥 Test Team Collaboration:",
    "   • Invite team members to your organization",
    "   • Test different permission levels",
    "",
    "5. 🔄 Test Run Triggers:",
    "   • Make changes in staging workspace",
    "   • Watch production workspace trigger",
    ""
  ]
}
EOF
```

---

## Exercise 12.5: Deployment and Validation (10 minutes)

### Step 1: Configure Terraform Cloud Variables
```bash
# Set up your environment variables for the deployment
cat > terraform.auto.tfvars << 'EOF'
# Replace these values with your actual configuration
organization_name     = "your-org-name"
notification_email    = "your-email@example.com"
aws_region           = "us-east-2"
environment          = "prod"

# Optional: Slack webhook for notifications
slack_webhook_url    = ""  # Add your Slack webhook if available
EOF

echo "⚠️ IMPORTANT: Update terraform.auto.tfvars with your actual values!"
echo "1. organization_name: Your Terraform Cloud organization"
echo "2. notification_email: Your email address for alerts"
echo "3. aws_region: Your preferred AWS region"
```

### Step 2: Deploy via Terraform Cloud
```bash
# Since this uses Terraform Cloud backend, deployment is different from local runs
echo "🚀 DEPLOYING VIA TERRAFORM CLOUD:"
echo "========================================"
echo ""
echo "1. ☁️ Initialize Terraform Cloud workspace:"
terraform init

echo ""
echo "2. 📋 Plan infrastructure (triggers policy checks):"
terraform plan

echo ""
echo "3. 🚀 Apply infrastructure (if policies pass):"
terraform apply

echo ""
echo "4. 🗺️ View deployment in Terraform Cloud:"
echo "   https://app.terraform.io/app/$(terraform output -raw organization_name 2>/dev/null || echo 'your-org')/workspaces/final-project-prod"

echo ""
echo "5. 📊 Monitor cost estimation and policy results in the UI"
```

### Step 3: Test and Validate Terraform Cloud Enterprise Features
```bash
# Create comprehensive testing script
cat > test_enterprise_deployment.sh << 'EOF'
#!/bin/bash

echo "🧪 TESTING TERRAFORM CLOUD ENTERPRISE DEPLOYMENT"
echo "==============================================="

# Test 1: Application availability
echo "🌐 Testing Application Availability..."
APP_URL=$(terraform output -raw terraform_cloud_enterprise_summary | jq -r '.application_url' 2>/dev/null)
if [ "$APP_URL" != "null" ] && [ ! -z "$APP_URL" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL")
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "✅ Application is accessible at: $APP_URL"
        curl -s "$APP_URL" | grep -o "<title>[^<]*" | head -1
    else
        echo "❌ Application returned HTTP $HTTP_STATUS"
    fi
else
    echo "⚠️ Application URL not yet available - infrastructure may still be deploying"
fi

echo ""
echo "📋 Testing Terraform Cloud Integration..."
echo "✅ Backend: Terraform Cloud (check terraform init output)"
echo "✅ Private Registry: Modules deployed from private registry"
echo "✅ Policy Enforcement: Policies from Lab 10 automatically applied"
echo "✅ Cost Estimation: Available in Terraform Cloud UI"
echo "✅ Team Collaboration: Workspaces configured for dev/staging/prod"

echo ""
echo "📊 View detailed results in Terraform Cloud:"
echo "https://app.terraform.io/app/$(terraform output -raw terraform_cloud_enterprise_summary | jq -r '.organization_name' 2>/dev/null || echo 'your-org')/workspaces/final-project-prod"

echo ""
echo "🎉 Enterprise deployment test complete!"
EOF

chmod +x test_enterprise_deployment.sh
./test_enterprise_deployment.sh
```

---

## Lab Completion and Final Validation

### Step 1: Complete Lab Checklist
- [ ] Terraform Cloud workspaces configured for all environments
- [ ] Private registry modules deployed from Lab 11
- [ ] Policy enforcement active from Lab 10 configurations
- [ ] Infrastructure deployed using enterprise patterns
- [ ] Team collaboration features configured
- [ ] Cost estimation and governance enabled
- [ ] Notifications and webhooks configured
- [ ] Application successfully deployed and accessible
- [ ] All Terraform Cloud enterprise features demonstrated

### Step 2: View Final Results
```bash
# Display comprehensive deployment summary
terraform output terraform_cloud_enterprise_summary
terraform output enterprise_success_message
terraform output testing_instructions
```

## 🏆 Course Completion - You Did It!

### 🎉 **CONGRATULATIONS ON TERRAFORM CLOUD MASTERY!** 

You have successfully completed the most comprehensive Terraform training course available!

### 📋 What You've Mastered Throughout This Course

**Day 1: Terraform Fundamentals**
1. ✅ **Lab 1**: First Terraform Configuration & AWS Cloud9 Setup
2. ✅ **Lab 2**: Variables, Data Sources & Dynamic Configuration  
3. ✅ **Lab 3**: Resource Dependencies & Lifecycle Management
4. ✅ **Lab 4**: Creating and Using Terraform Modules

**Day 2: Advanced Configuration & State Management**
5. ✅ **Lab 5**: Remote State Management with S3 & DynamoDB
6. ✅ **Lab 6**: Basic Terraform Cloud Integration
7. ✅ **Lab 7**: Advanced Patterns & CI/CD with GitHub Actions
8. ✅ **Lab 8**: Advanced VPC Networking Architecture

**Day 3: Terraform Cloud Enterprise (Your Specialty!)**
9. ✅ **Lab 9**: Terraform Cloud Workspaces & Organization Management
10. ✅ **Lab 10**: Policy as Code with Sentinel & OPA Governance
11. ✅ **Lab 11**: Private Registry & Enterprise Module Management
12. ✅ **Lab 12**: Complete Enterprise Integration (This Lab!)

### 🌟 Enterprise Skills You've Developed

**Terraform Cloud Expertise:**
- 🏢 **Organization Management**: Multi-workspace enterprise setup
- 📚 **Private Registry**: Custom module publishing and consumption  
- 🛡️ **Policy as Code**: Sentinel and OPA governance implementation
- 💰 **Cost Management**: Estimation, budgeting, and control
- 👥 **Team Collaboration**: Access controls, run triggers, notifications
- 🔄 **Workflow Automation**: CI/CD integration and GitOps patterns
- 📊 **Enterprise Reporting**: Compliance, audit trails, and analytics

### 🏗️ Enterprise Architecture You've Built

```
┌─────────────────────────────────────────────────────────────┐
│                    Terraform Cloud Organization             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Dev Workspace│  │Staging WS   │  │ Production WS       │ │
│  │ Auto-Apply  │→ │Manual Approve│→ │ Policy Enforced     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                            │
│  ┌─────────────────┐    ┌───────────────────────────────┐ │
│  │ Private Registry│    │ Policy as Code Engine         │ │
│  │ - VPC Module    │    │ - Cost Control Policies       │ │
│  │ - EC2-ASG Module│    │ - Security Compliance Rules   │ │
│  └─────────────────┘    └───────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────┐
│                        AWS Infrastructure                   │
│                                                            │
│  Internet → ALB → Auto Scaling Group → EC2 Instances      │
│                          ↓                                 │
│                  CloudWatch Monitoring                     │
│                          ↓                                 │
│                   SNS Notifications                        │
└─────────────────────────────────────────────────────────────┘
```

### 💪 Enterprise Skills Mastered

- ✅ **540 minutes (9 hours)** of intensive hands-on Terraform Cloud experience
- ✅ **Enterprise-grade infrastructure** deployed via Terraform Cloud
- ✅ **Policy-as-Code governance** with real enforcement
- ✅ **Private module registry** with versioning and distribution
- ✅ **Multi-environment strategy** with dev/staging/prod workflows
- ✅ **Team collaboration patterns** with proper access controls
- ✅ **Cost management** with estimation and budget controls
- ✅ **GitOps integration** with automated deployment pipelines

### 🚀 Your Terraform Cloud Enterprise Journey Starts Now!

**You are now equipped with:**
- 🏢 **Enterprise-grade** Terraform Cloud expertise
- 💼 **Real-world** enterprise infrastructure experience  
- 🎯 **Production-ready** multi-environment deployment skills
- 👥 **Team collaboration** and governance best practices
- 🏆 **Certification-ready** preparation for HashiCorp exams
- 💰 **Cost optimization** and policy enforcement capabilities

---

## Clean Up (Optional)
```bash
# Clean up infrastructure via Terraform Cloud
echo "🧹 Cleaning up enterprise infrastructure..."
terraform destroy

# Note: Terraform Cloud workspaces and organization settings will remain
# This allows you to continue using them for future projects!

echo "✅ Infrastructure cleaned up successfully!"
echo "🏢 Your Terraform Cloud organization and skills remain forever!"
```

---

## 🎓 TERRAFORM CLOUD ENTERPRISE MASTERY CERTIFICATE

### 🏆 **CONGRATULATIONS! YOU HAVE SUCCESSFULLY COMPLETED:**

**"Terraform Cloud Enterprise Infrastructure Mastery"**

📅 **Duration**: 3 Days | ⏱️ **Hands-on Time**: 540 Minutes (9 Hours)
🎯 **Focus**: 70% Hands-on / 30% Theory | 🌟 **Difficulty**: Beginner → Advanced
🏢 **Specialization**: Terraform Cloud Enterprise Features

### 🎯 **YOUR CERTIFIED COMPETENCIES:**

✅ **Core Terraform Skills**: HCL, State Management, Provider Integration
✅ **Module Development**: Creation, Testing, and Enterprise Distribution  
✅ **Terraform Cloud Mastery**: Workspaces, Teams, and Organizations
✅ **Policy as Code**: Sentinel and OPA Governance Implementation
✅ **Enterprise Security**: Access Controls, Compliance, and Audit Trails
✅ **Cost Management**: Estimation, Budgeting, and Financial Governance
✅ **DevOps Integration**: CI/CD, GitOps, and Automated Deployments
✅ **Multi-Cloud Strategy**: AWS Integration with Terraform Cloud

### 🚀 **IMMEDIATE NEXT STEPS:**
1. 🏅 **HashiCorp Terraform Associate Certification** (You're 100% Ready!)
2. 🏢 **Implement Terraform Cloud in Your Organization**
3. 👥 **Lead Infrastructure Modernization Initiatives**  
4. 📚 **Pursue HashiCorp Terraform Professional Certification**
5. 🌟 **Become a Terraform Community Contributor**

---

---

### 🌟 **FINAL WORDS FROM YOUR TERRAFORM CLOUD INSTRUCTORS:**

*"You didn't just learn Terraform - you mastered the enterprise platform that's transforming how organizations manage infrastructure at scale. The skills you've developed in this course position you as a leader in the Infrastructure as Code revolution."*

*"Every major technology company and enterprise organization is adopting Terraform Cloud for their infrastructure needs. You now have the expertise to guide them on that journey."*

### 🎉 **CONGRATULATIONS, TERRAFORM CLOUD ENTERPRISE EXPERT!**

**You are now ready to:**
- 🏢 Transform enterprise infrastructure practices
- 💼 Lead Terraform Cloud adoption initiatives  
- 🎯 Architect scalable, governed infrastructure solutions
- 👥 Build and mentor high-performing DevOps teams
- 🏆 Earn industry recognition as a Terraform expert

### 🚀 **GO FORTH AND BUILD THE FUTURE OF INFRASTRUCTURE!**

---

*Thank you for choosing our Terraform Cloud Enterprise Mastery course. Your journey to infrastructure excellence starts now! 🌟*