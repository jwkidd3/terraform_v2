# Lab 10: Terraform Cloud Teams and Workspaces
**Duration:** 45 minutes  
**Difficulty:** Intermediate to Advanced  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## Multi-User Environment Setup
**IMPORTANT:** This lab supports multiple users working simultaneously. Each user must configure a unique username to prevent resource conflicts.

### Before You Begin
1. Choose a unique username (e.g., user1, user2, john, mary, etc.)
2. Use this username consistently throughout the lab
3. Create separate teams and workspaces for your user
4. All Terraform Cloud resources will be prefixed with your username
5. This ensures complete isolation between users in Terraform Cloud

**Example:** If your username is "user1", your resources will be named:
- Team: `user1-developers`, `user1-admins`
- Workspaces: `user1-development`, `user1-staging`, `user1-production`
- AWS resources: `user1-` prefixed

---

## Lab Objectives
By the end of this lab, you will be able to:
- Create and manage teams in Terraform Cloud
- Implement role-based access control (RBAC)
- Configure workspace permissions and access levels
- Set up variable sets for shared configuration
- Implement run triggers for automated workflows
- Manage multiple workspaces efficiently

---

## Prerequisites
- Completion of Lab 9 (Introduction to Terraform Cloud)
- Active Terraform Cloud organization
- Understanding of workspace concepts
- Basic AWS and Terraform knowledge

---

## Exercise 10.1: Advanced Workspace Management
**Duration:** 15 minutes

### Step 1: Create Multi-Environment Project Structure
```bash
# Create new project directory
mkdir terraform-cloud-teams
cd terraform-cloud-teams

# Create directory structure
mkdir -p {environments/{dev,staging,prod},shared/modules,policies}

# Create shared infrastructure module
mkdir -p shared/modules/web-app/{variables,outputs,main}
```

### Step 2: Create Shared Web Application Module
```bash
# Create the web application module
cat > shared/modules/web-app/main.tf << 'EOF'
# Web Application Module
terraform {
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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = var.public_subnet_count
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Environment = var.environment
    Type        = "public"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
  }
}

# Associate route table with public subnets
resource "aws_route_table_association" "public" {
  count = var.public_subnet_count
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id
  
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
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# Security Group for EC2 Instances
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
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
    Name        = "${var.project_name}-${var.environment}-ec2-sg"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-tg"
    Environment = var.environment
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    environment = var.environment
    project     = var.project_name
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-instance"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-asg"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}
EOF

# Create user data script
cat > shared/modules/web-app/userdata.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create simple web page
cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head>
    <title>${project} - ${environment}</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; background-color: #f0f0f0; }
        .container { margin: 50px auto; padding: 20px; background: white; border-radius: 10px; max-width: 600px; }
        h1 { color: #333; }
        .env { background: #007acc; color: white; padding: 5px 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to ${project}</h1>
        <p>Environment: <span class="env">${environment}</span></p>
        <p>Server: $(hostname)</p>
        <p>Managed by Terraform Cloud</p>
    </div>
</body>
</html>
HTML

systemctl restart httpd
EOF

# Create module variables
cat > shared/modules/web-app/variables.tf << 'EOF'
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

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}
EOF

# Create module outputs
cat > shared/modules/web-app/outputs.tf << 'EOF'
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "URL of the load balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "security_group_ids" {
  description = "Security group IDs"
  value = {
    alb = aws_security_group.alb.id
    ec2 = aws_security_group.ec2.id
  }
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.main.arn
}
EOF
```

---

## Exercise 10.2: Team and User Management
**Duration:** 15 minutes

### Step 1: Create Environment-Specific Configurations
```bash
# Create development environment
cat > environments/dev/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  cloud {
    organization = "YOUR_ORG_NAME"  # Replace with your org
    
    workspaces {
      name = "web-app-dev"
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

module "web_app" {
  source = "../../shared/modules/web-app"
  
  project_name     = var.project_name
  environment      = "dev"
  vpc_cidr        = "10.0.0.0/16"
  instance_type   = "t2.micro"
  min_size        = 1
  max_size        = 2
  desired_capacity = 1
}
EOF

# Create staging environment
cat > environments/staging/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  cloud {
    organization = "YOUR_ORG_NAME"  # Replace with your org
    
    workspaces {
      name = "web-app-staging"
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

module "web_app" {
  source = "../../shared/modules/web-app"
  
  project_name     = var.project_name
  environment      = "staging"
  vpc_cidr        = "10.1.0.0/16"
  instance_type   = "t2.small"
  min_size        = 2
  max_size        = 4
  desired_capacity = 2
}
EOF

# Create production environment
cat > environments/prod/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  cloud {
    organization = "YOUR_ORG_NAME"  # Replace with your org
    
    workspaces {
      name = "web-app-prod"
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

module "web_app" {
  source = "../../shared/modules/web-app"
  
  project_name     = var.project_name
  environment      = "prod"
  vpc_cidr        = "10.2.0.0/16"
  instance_type   = "t3.small"
  min_size        = 2
  max_size        = 6
  desired_capacity = 3
}
EOF

# Create shared variables for all environments
for env in dev staging prod; do
cat > environments/${env}/variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "webapp-demo"
}
EOF

cat > environments/${env}/outputs.tf << 'EOF'
output "application_url" {
  description = "URL to access the application"
  value       = module.web_app.load_balancer_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.web_app.vpc_id
}

output "environment_info" {
  description = "Environment information"
  value = {
    environment = "dev"
    vpc_cidr   = "10.0.0.0/16"
    region     = var.aws_region
  }
}
EOF
done
```

### Step 2: Create Teams with Terraform Configuration
```bash
# Create team management configuration
cat > team-management.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  cloud {
    organization = "YOUR_ORG_NAME"  # Replace with your org
    
    workspaces {
      name = "team-management"
    }
  }
  
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.48"
    }
  }
}

provider "tfe" {
  # Token is read from TF_CLOUD_TOKEN environment variable
  # or from ~/.terraform.d/credentials.tfrc.json
}

# Get organization data
data "tfe_organization" "main" {
  name = var.organization_name
}

# Create teams
resource "tfe_team" "developers" {
  name         = "developers"
  organization = data.tfe_organization.main.name
  visibility   = "organization"
  
  organization_access {
    read_workspaces   = true
    read_projects     = true
  }
}

resource "tfe_team" "staging_reviewers" {
  name         = "staging-reviewers"
  organization = data.tfe_organization.main.name
  visibility   = "organization"
  
  organization_access {
    read_workspaces   = true
    read_projects     = true
  }
}

resource "tfe_team" "production_operators" {
  name         = "production-operators"
  organization = data.tfe_organization.main.name
  visibility   = "organization"
  
  organization_access {
    manage_workspaces = true
    manage_projects   = true
  }
}

# Create workspaces
resource "tfe_workspace" "dev" {
  name         = "web-app-dev"
  organization = data.tfe_organization.main.name
  description  = "Development environment for web application"
  
  auto_apply            = true
  file_triggers_enabled = true
  queue_all_runs        = false
  terraform_version     = "1.6.6"
  working_directory     = "environments/dev"
  
  execution_mode = "remote"
  
  tag_names = ["development", "web-app", "auto-deploy"]
}

resource "tfe_workspace" "staging" {
  name         = "web-app-staging"
  organization = data.tfe_organization.main.name
  description  = "Staging environment for web application"
  
  auto_apply            = false
  file_triggers_enabled = true
  queue_all_runs        = false
  terraform_version     = "1.6.6"
  working_directory     = "environments/staging"
  
  execution_mode = "remote"
  
  tag_names = ["staging", "web-app", "manual-approve"]
}

resource "tfe_workspace" "prod" {
  name         = "web-app-prod"
  organization = data.tfe_organization.main.name
  description  = "Production environment for web application"
  
  auto_apply            = false
  file_triggers_enabled = false
  queue_all_runs        = false
  terraform_version     = "1.6.6"
  working_directory     = "environments/prod"
  
  execution_mode = "remote"
  
  tag_names = ["production", "web-app", "manual-only"]
}

# Set team permissions for workspaces
resource "tfe_team_access" "dev_developers" {
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.dev.id
  
  permissions {
    runs              = "apply"
    variables         = "write"
    state_versions    = "read"
    sentinel_mocks    = "none"
    workspace_locking = false
  }
}

resource "tfe_team_access" "staging_developers" {
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.staging.id
  
  permissions {
    runs              = "plan"
    variables         = "read"
    state_versions    = "read"
    sentinel_mocks    = "none"
    workspace_locking = false
  }
}

resource "tfe_team_access" "staging_reviewers" {
  team_id      = tfe_team.staging_reviewers.id
  workspace_id = tfe_workspace.staging.id
  
  permissions {
    runs              = "apply"
    variables         = "write"
    state_versions    = "read"
    sentinel_mocks    = "read"
    workspace_locking = true
  }
}

resource "tfe_team_access" "prod_operators" {
  team_id      = tfe_team.production_operators.id
  workspace_id = tfe_workspace.prod.id
  
  permissions {
    runs              = "apply"
    variables         = "write"
    state_versions    = "write"
    sentinel_mocks    = "read"
    workspace_locking = true
  }
}

# Create variable sets
resource "tfe_variable_set" "aws_credentials" {
  name         = "aws-credentials"
  description  = "AWS credentials for all workspaces"
  organization = data.tfe_organization.main.name
  global       = false
  
  workspace_ids = [
    tfe_workspace.dev.id,
    tfe_workspace.staging.id,
    tfe_workspace.prod.id
  ]
}

# AWS environment variables (sensitive)
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

resource "tfe_variable" "aws_default_region" {
  key             = "AWS_DEFAULT_REGION"
  value           = "us-east-2"
  category        = "env"
  variable_set_id = tfe_variable_set.aws_credentials.id
  description     = "AWS Default Region"
}

# Run triggers (dev -> staging -> prod)
resource "tfe_run_trigger" "dev_to_staging" {
  workspace_id  = tfe_workspace.staging.id
  sourceable_id = tfe_workspace.dev.id
}

resource "tfe_run_trigger" "staging_to_prod" {
  workspace_id  = tfe_workspace.prod.id
  sourceable_id = tfe_workspace.staging.id
}

# Notification configurations
resource "tfe_notification_configuration" "dev_slack" {
  count = var.slack_webhook_url != "" ? 1 : 0
  
  name             = "dev-notifications"
  enabled          = true
  destination_type = "slack"
  url              = var.slack_webhook_url
  workspace_id     = tfe_workspace.dev.id
  
  triggers = [
    "run:completed",
    "run:errored"
  ]
}

resource "tfe_notification_configuration" "prod_email" {
  name             = "prod-notifications"
  enabled          = true
  destination_type = "email"
  email_addresses  = var.notification_emails
  workspace_id     = tfe_workspace.prod.id
  
  triggers = [
    "run:needs_attention",
    "run:completed",
    "run:errored"
  ]
}
EOF

# Create variables for team management
cat > team-variables.tf << 'EOF'
variable "organization_name" {
  description = "Terraform Cloud organization name"
  type        = string
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

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
}

variable "notification_emails" {
  description = "Email addresses for notifications"
  type        = list(string)
  default     = ["admin@example.com"]
}
EOF

# Create outputs for team management
cat > team-outputs.tf << 'EOF'
output "team_information" {
  description = "Team structure and access levels"
  value = {
    developers = {
      name = tfe_team.developers.name
      id   = tfe_team.developers.id
      dev_access = "full (plan/apply)"
      staging_access = "read-only (plan only)"
      prod_access = "none"
    }
    staging_reviewers = {
      name = tfe_team.staging_reviewers.name
      id   = tfe_team.staging_reviewers.id
      dev_access = "none"
      staging_access = "full (plan/apply)"
      prod_access = "none"
    }
    production_operators = {
      name = tfe_team.production_operators.name
      id   = tfe_team.production_operators.id
      dev_access = "none"
      staging_access = "none"
      prod_access = "full (plan/apply)"
    }
  }
}

output "workspace_information" {
  description = "Workspace configuration and URLs"
  value = {
    dev = {
      name = tfe_workspace.dev.name
      url  = "https://app.terraform.io/app/${var.organization_name}/workspaces/${tfe_workspace.dev.name}"
      auto_apply = tfe_workspace.dev.auto_apply
    }
    staging = {
      name = tfe_workspace.staging.name
      url  = "https://app.terraform.io/app/${var.organization_name}/workspaces/${tfe_workspace.staging.name}"
      auto_apply = tfe_workspace.staging.auto_apply
    }
    prod = {
      name = tfe_workspace.prod.name
      url  = "https://app.terraform.io/app/${var.organization_name}/workspaces/${tfe_workspace.prod.name}"
      auto_apply = tfe_workspace.prod.auto_apply
    }
  }
}

output "run_triggers" {
  description = "Configured run triggers"
  value = {
    dev_to_staging = {
      source = tfe_workspace.dev.name
      target = tfe_workspace.staging.name
    }
    staging_to_prod = {
      source = tfe_workspace.staging.name
      target = tfe_workspace.prod.name
    }
  }
}
EOF
```

---

## Exercise 10.3: Testing Team Workflows and Permissions
**Duration:** 15 minutes

### Step 1: Deploy Team Management Infrastructure
```bash
# Create terraform.tfvars for team management
cat > terraform.tfvars << 'EOF'
organization_name = "YOUR_ORG_NAME"  # Replace with your org

# Set these as environment variables or uncomment:
# aws_access_key_id     = "your-access-key"
# aws_secret_access_key = "your-secret-key"

notification_emails = ["your-email@example.com"]
# slack_webhook_url = "https://hooks.slack.com/services/xxx/yyy/zzz"
EOF

# Set AWS credentials as environment variables
export TF_VAR_aws_access_key_id="$AWS_ACCESS_KEY_ID"
export TF_VAR_aws_secret_access_key="$AWS_SECRET_ACCESS_KEY"

# Initialize and apply team management
terraform init
terraform plan
terraform apply -auto-approve

# View outputs
terraform output team_information
terraform output workspace_information
```

### Step 2: Test Workspace Deployments
```bash
# Deploy development environment first
cd environments/dev

# Initialize and deploy dev
terraform init
terraform plan
terraform apply -auto-approve

# Get the application URL
terraform output application_url

# Test the application
APP_URL=$(terraform output -raw application_url)
echo "Testing application at: $APP_URL"
curl -s "$APP_URL" | grep -o '<title>.*</title>'

cd ../..
```

### Step 3: Test Run Triggers
```bash
# Make a change to trigger staging deployment
cd environments/dev

# Update the desired capacity
cat > terraform.tfvars << 'EOF'
project_name = "webapp-demo"
aws_region   = "us-east-2"
EOF

# Update main.tf to change desired capacity
sed -i 's/desired_capacity = 1/desired_capacity = 2/' main.tf

# Apply the change (this should trigger staging)
terraform plan
terraform apply -auto-approve

cd ../..

# Monitor the run trigger in Terraform Cloud UI
echo "Check Terraform Cloud UI for triggered runs:"
echo "1. Dev workspace should show completed run"
echo "2. Staging workspace should show triggered run"
echo "Visit: https://app.terraform.io/app/YOUR_ORG_NAME/workspaces/web-app-staging/runs"
```

### Step 4: Create Team Invitation Script
```bash
# Create script to invite team members
cat > invite-team-members.sh << 'EOF'
#!/bin/bash

# Script to invite team members to Terraform Cloud organization
# Replace YOUR_ORG_NAME with your actual organization name
# Replace YOUR_TFC_TOKEN with your actual API token

ORG_NAME="YOUR_ORG_NAME"
TFC_TOKEN="YOUR_TFC_TOKEN"

# Function to invite user to organization
invite_user() {
  local email=$1
  local teams=$2
  
  echo "Inviting $email to organization..."
  
  # Create invitation
  invitation_response=$(curl -s \
    --header "Authorization: Bearer $TFC_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request POST \
    --data @- \
    "https://app.terraform.io/api/v2/organizations/$ORG_NAME/organization-memberships" <<EOF
{
  "data": {
    "type": "organization-memberships",
    "attributes": {
      "email": "$email"
    }
  }
}
EOF
  )
  
  # Extract membership ID
  membership_id=$(echo "$invitation_response" | jq -r '.data.id')
  
  if [ "$membership_id" != "null" ]; then
    echo "✅ Invitation sent to $email (ID: $membership_id)"
    
    # Add to specified teams
    IFS=',' read -ra TEAM_ARRAY <<< "$teams"
    for team in "${TEAM_ARRAY[@]}"; do
      echo "  Adding to team: $team"
      
      # Get team ID
      team_id=$(curl -s \
        --header "Authorization: Bearer $TFC_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        "https://app.terraform.io/api/v2/organizations/$ORG_NAME/teams/$team" | \
        jq -r '.data.id')
      
      if [ "$team_id" != "null" ]; then
        # Add user to team
        curl -s \
          --header "Authorization: Bearer $TFC_TOKEN" \
          --header "Content-Type: application/vnd.api+json" \
          --request POST \
          --data @- \
          "https://app.terraform.io/api/v2/teams/$team_id/team-memberships" <<EOF
{
  "data": {
    "type": "team-memberships",
    "relationships": {
      "organization-membership": {
        "data": {
          "type": "organization-memberships",
          "id": "$membership_id"
        }
      }
    }
  }
}
EOF
        echo "    ✅ Added to team: $team"
      else
        echo "    ❌ Team not found: $team"
      fi
    done
  else
    echo "❌ Failed to invite $email"
  fi
}

# Example invitations (replace with real email addresses)
echo "=== Terraform Cloud Team Invitations ==="
echo

# Invite developers
invite_user "developer1@example.com" "developers"
invite_user "developer2@example.com" "developers"

# Invite staging reviewers
invite_user "reviewer1@example.com" "staging-reviewers"
invite_user "reviewer2@example.com" "staging-reviewers"

# Invite production operators
invite_user "ops1@example.com" "production-operators"
invite_user "ops2@example.com" "production-operators"

echo
echo "=== Invitation Summary ==="
echo "All invitations sent! Users will receive email invitations."
echo "They need to:"
echo "1. Accept the invitation"
echo "2. Create/use their Terraform Cloud account"
echo "3. They'll automatically be added to assigned teams"
EOF

chmod +x invite-team-members.sh

echo "Team invitation script created: invite-team-members.sh"
echo "Edit the script with real email addresses and run when ready"
```

---

## Lab Summary and Key Takeaways

### What You've Learned

1. **Advanced Workspace Management:**
   - Multi-environment workspace strategies
   - Workspace settings and configurations
   - Working directory and VCS integration

2. **Team and Access Management:**
   - Creating and managing teams programmatically
   - Role-based access control (RBAC)
   - Different permission levels for different environments

3. **Variable Management:**
   - Variable sets for shared configuration
   - Environment vs Terraform variables
   - Sensitive variable handling across workspaces

4. **Automation and Workflows:**
   - Run triggers for automated deployments
   - Notification configurations
   - Multi-environment deployment pipelines

5. **Security and Compliance:**
   - Environment isolation
   - Graduated permissions (dev → staging → prod)
   - Audit trails through Terraform Cloud

### Team Structure Implemented

```
Organization: YOUR_ORG_NAME
├── Teams
│   ├── developers (dev: full, staging: plan-only)
│   ├── staging-reviewers (staging: full)
│   └── production-operators (prod: full)
├── Variable Sets
│   └── aws-credentials (shared across all workspaces)
└── Workspaces
    ├── web-app-dev (auto-apply) → triggers →
    ├── web-app-staging (manual) → triggers →
    └── web-app-prod (manual, locked down)
```

### Deployment Pipeline Flow

1. **Developer pushes code** → Dev workspace auto-deploys
2. **Dev deployment succeeds** → Triggers staging workspace
3. **Staging reviewer approves** → Staging deployment runs
4. **Staging succeeds** → Triggers production workspace
5. **Production operator approves** → Production deployment

### Clean Up
```bash
# Clean up in reverse order
cd environments/dev
terraform destroy -auto-approve

cd ../../
terraform destroy -auto-approve

echo "All resources cleaned up!"
```

---

## Next Steps
In Lab 11, you'll learn about:
- Sentinel and OPA policy enforcement
- Cost estimation and budget controls
- Private registry and module management
- Advanced governance features

---

## Troubleshooting

### Common Issues and Solutions

1. **Team Creation Fails**
   ```bash
   # Verify organization permissions
   curl -H "Authorization: Bearer $TF_CLOUD_TOKEN" \
        "https://app.terraform.io/api/v2/organizations/YOUR_ORG_NAME" | jq '.data.attributes'
   ```

2. **Workspace Access Issues**
   ```bash
   # Check team memberships
   curl -H "Authorization: Bearer $TF_CLOUD_TOKEN" \
        "https://app.terraform.io/api/v2/teams/TEAM_ID/team-memberships"
   ```

3. **Run Triggers Not Working**
   - Ensure source workspace runs complete successfully
   - Check workspace settings for run triggers
   - Verify proper permissions on target workspace

4. **Variable Set Issues**
   - Ensure variables are properly scoped to workspaces
   - Check environment vs Terraform variable categories
   - Verify sensitive variables are marked correctly

5. **Module Path Issues**
   - Verify relative paths in module sources
   - Ensure working directory is set correctly in workspace
   - Check file structure matches expected paths