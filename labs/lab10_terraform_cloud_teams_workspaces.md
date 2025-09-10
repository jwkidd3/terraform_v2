# Lab 10: Advanced Terraform Cloud Workspaces and Team Management
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 3  
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Advanced Learning Objectives**
By the end of this lab, you will be able to:
- Implement sophisticated multi-workspace architecture with environment promotion
- Configure advanced workspace settings including VCS integration and triggers
- Build complex variable hierarchies with workspace inheritance
- Design team-based access control with role-based permissions
- Implement workspace automation with run triggers and notifications
- Use workspace tags and metadata for governance at scale

---

## 📋 **Prerequisites**
- Completion of Lab 9 (Terraform Cloud Integration)
- Terraform Cloud account with organization admin access
- GitHub account for VCS integration
- Understanding of enterprise infrastructure patterns
- AWS CLI configured with appropriate permissions

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 10.1: Multi-Environment Workspace Architecture (20 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab10
cd terraform-lab10
```

### Step 2: Create Enterprise-Grade Multi-Environment Configuration
We'll build a sophisticated infrastructure stack that demonstrates advanced workspace patterns:

**main.tf:**
```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  # Advanced workspace configuration with tags
  cloud {
    organization = "user1-terraform-lab"  # Replace user1 with your username!
    
    workspaces {
      name = "user1-dev-app-stack"      # Replace user1 with your username!
      tags = ["environment:dev", "stack:application", "owner:${var.username}"]
    }
  }
}

# Data sources for dynamic configuration
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

provider "aws" {
  region = "us-east-2"
  
  default_tags {
    tags = local.common_tags
  }
}

variable "username" {
  description = "Your unique username"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.username))
    error_message = "Username must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "application_name" {
  description = "Name of the application stack"
  type        = string
  default     = "webapp"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (workspace-specific)"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "enable_monitoring" {
  description = "Enable advanced monitoring and alerting"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

variable "team_access" {
  description = "Team access configuration"
  type = object({
    developers = list(string)
    operations = list(string)
    readonly   = list(string)
  })
  default = {
    developers = []
    operations = []
    readonly   = []
  }
}

# Advanced environment-specific configuration
locals {
  # Environment-specific scaling and performance settings
  environment_config = {
    dev = {
      instance_type           = "t3.micro"
      min_size               = 1
      max_size               = 2
      desired_capacity       = 1
      enable_deletion_protection = false
      backup_window          = "03:00-04:00"
      maintenance_window     = "sun:04:00-sun:05:00"
      multi_az               = false
      storage_encrypted      = false
    }
    staging = {
      instance_type           = "t3.small"
      min_size               = 1
      max_size               = 4
      desired_capacity       = 2
      enable_deletion_protection = false
      backup_window          = "02:00-03:00"
      maintenance_window     = "sun:03:00-sun:04:00"
      multi_az               = true
      storage_encrypted      = true
    }
    prod = {
      instance_type           = "t3.medium"
      min_size               = 2
      max_size               = 8
      desired_capacity       = 3
      enable_deletion_protection = true
      backup_window          = "01:00-02:00"
      maintenance_window     = "sun:02:00-sun:03:00"
      multi_az               = true
      storage_encrypted      = true
    }
  }
  
  current_config = local.environment_config[var.environment]
  
  # Advanced workspace metadata
  workspace_metadata = {
    workspace_name     = terraform.workspace
    environment       = var.environment
    application       = var.application_name
    created_by        = "terraform-cloud"
    cost_center       = "engineering"
    compliance_level  = var.environment == "prod" ? "high" : "standard"
  }
  
  # Comprehensive tagging strategy
  common_tags = merge(
    local.workspace_metadata,
    {
      Owner       = var.username
      Lab         = "10-advanced"
      ManagedBy   = "TerraformCloud"
      Environment = var.environment
      VPC_CIDR    = var.vpc_cidr
      Monitoring  = var.enable_monitoring ? "enabled" : "disabled"
      Terraform   = "true"
    }
  )
  
  # Network configuration with workspace-specific CIDR
  availability_zones = data.aws_availability_zones.available.names
  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2)
  ]
  private_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 11),
    cidrsubnet(var.vpc_cidr, 8, 12)
  ]
  database_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 21),
    cidrsubnet(var.vpc_cidr, 8, 22)
  ]
}

# Environment-specific S3 bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.username}-${var.environment}-app-bucket"

  tags = merge(local.common_tags, {
    Name = "${var.username}-${var.environment}-app-bucket"
  })
}

# Conditional versioning based on environment
resource "aws_s3_bucket_versioning" "app_bucket" {
  count = local.bucket_versioning[var.environment] ? 1 : 0
  
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Environment configuration file
resource "aws_s3_object" "env_config" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "config/environment.json"
  content = jsonencode({
    environment = var.environment
    username = var.username
    workspace = terraform.workspace
    instance_type = local.instance_types[var.environment]
    versioning_enabled = local.bucket_versioning[var.environment]
    monitoring_enabled = local.monitoring_enabled[var.environment]
    deployed_by = "Terraform Cloud"
    deployed_at = timestamp()
    terraform_cloud_workspace = terraform.workspace
  })

  tags = local.common_tags
}

# Simple EC2 instance (environment-specific size)
resource "aws_instance" "app_server" {
  ami           = "ami-0ea3c35c5c3284d82"  # Amazon Linux 2 in us-east-2
  instance_type = local.instance_types[var.environment]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>${var.environment} Environment - ${var.username}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .dev { background-color: #e8f5e8; }
            .staging { background-color: #fff3cd; }
            .prod { background-color: #f8d7da; }
            .env-badge { padding: 10px 20px; border-radius: 5px; margin: 20px 0; }
        </style>
    </head>
    <body>
        <div class="env-badge ${var.environment}">
            <h1>🚀 ${var.environment} Environment</h1>
            <p><strong>Owner:</strong> ${var.username}</p>
            <p><strong>Deployed by:</strong> Terraform Cloud</p>
        </div>
        
        <h2>Workspace Information</h2>
        <table border="1" style="border-collapse: collapse; width: 100%;">
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Environment</td><td><strong>${var.environment}</strong></td></tr>
            <tr><td>Instance Type</td><td>${local.instance_types[var.environment]}</td></tr>
            <tr><td>Versioning</td><td>${local.bucket_versioning[var.environment] ? "Enabled" : "Disabled"}</td></tr>
            <tr><td>Monitoring</td><td>${local.monitoring_enabled[var.environment] ? "Full" : "Basic"}</td></tr>
            <tr><td>Owner</td><td>${var.username}</td></tr>
        </table>
        
        <h2>Terraform Cloud Benefits</h2>
        <ul>
            <li>✅ Separate workspace for each environment</li>
            <li>✅ Environment-specific variables and settings</li>
            <li>✅ Secure state management per workspace</li>
            <li>✅ Team collaboration and access control</li>
            <li>✅ Audit trail for all changes</li>
        </ul>
        
        <h2>Lab 10: Workspaces and Teams</h2>
        <p>This infrastructure demonstrates multiple workspace management in Terraform Cloud.</p>
    </body>
    </html>
HTML
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${var.username}-${var.environment}-server"
  })
}
```

**user_data.sh:**
```bash
#!/bin/bash
yum update -y
yum install -y httpd php php-json awscli

# Configure CloudWatch agent if monitoring is enabled
%{if enable_monitoring~}
yum install -y amazon-cloudwatch-agent
%{endif~}

# Start services
systemctl start httpd
systemctl enable httpd

# Create application structure
mkdir -p /var/www/html/{assets,config,health}

# Health check endpoint
cat > /var/www/html/health/index.php << 'PHP'
<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'healthy',
    'timestamp' => date('c'),
    'environment' => '${environment}',
    'workspace' => '${workspace_name}',
    'instance_id' => file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'),
    'availability_zone' => file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone')
]);
?>
PHP

# Main application with advanced workspace information
cat > /var/www/html/index.php << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Advanced Terraform Cloud Workspace - ${environment}</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px 20px; text-align: center; margin-bottom: 30px; border-radius: 10px; }
        .env-badge { display: inline-block; padding: 8px 16px; border-radius: 20px; font-weight: bold; text-transform: uppercase; margin: 10px 0; }
        .dev { background-color: #28a745; }
        .staging { background-color: #ffc107; color: #212529; }
        .prod { background-color: #dc3545; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border-left: 4px solid #667eea; }
        .card h3 { color: #667eea; margin-bottom: 15px; }
        .metric { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
        .metric:last-child { border-bottom: none; }
        .metric-label { font-weight: 600; }
        .metric-value { color: #667eea; font-weight: bold; }
        .status-good { color: #28a745; }
        .status-warn { color: #ffc107; }
        .status-error { color: #dc3545; }
        .feature-list { list-style: none; }
        .feature-list li { padding: 8px 0; }
        .feature-list li:before { content: '✅ '; margin-right: 8px; }
        .workspace-info { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .code { background: #2d3748; color: #e2e8f0; padding: 15px; border-radius: 5px; font-family: 'Courier New', monospace; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏗️ Advanced Terraform Cloud Architecture</h1>
            <div class="env-badge ${environment}">${environment} Environment</div>
            <p>Multi-Workspace Infrastructure Management | Owner: ${username}</p>
        </div>

        <div class="grid">
            <!-- Workspace Information -->
            <div class="card">
                <h3>🌐 Workspace Details</h3>
                <div class="metric">
                    <span class="metric-label">Workspace Name:</span>
                    <span class="metric-value">${workspace_name}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Environment:</span>
                    <span class="metric-value">${environment}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Application:</span>
                    <span class="metric-value">${application_name}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Owner:</span>
                    <span class="metric-value">${username}</span>
                </div>
            </div>

            <!-- Infrastructure Configuration -->
            <div class="card">
                <h3>⚙️ Infrastructure Config</h3>
                <div class="metric">
                    <span class="metric-label">Instance Type:</span>
                    <span class="metric-value">${instance_type}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">VPC CIDR:</span>
                    <span class="metric-value">${vpc_cidr}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Multi-AZ:</span>
                    <span class="metric-value ${multi_az ? "status-good" : "status-warn"}">${multi_az ? "Enabled" : "Disabled"}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Storage Encryption:</span>
                    <span class="metric-value ${storage_encrypted ? "status-good" : "status-warn"}">${storage_encrypted ? "Enabled" : "Disabled"}</span>
                </div>
            </div>

            <!-- Advanced Features -->
            <div class="card">
                <h3>🚀 Advanced Features</h3>
                <ul class="feature-list">
                    <li>Application Load Balancer</li>
                    <li>Auto Scaling Groups</li>
                    <li>Multi-tier networking</li>
                    <li>CloudWatch monitoring</li>
                    <li>S3 lifecycle policies</li>
                    <li>IAM role-based access</li>
                    <li>Health check endpoints</li>
                    <li>Security group isolation</li>
                </ul>
            </div>

            <!-- Terraform Cloud Features -->
            <div class="card">
                <h3>☁️ Terraform Cloud Benefits</h3>
                <ul class="feature-list">
                    <li>Advanced workspace management</li>
                    <li>Team-based access control</li>
                    <li>Environment-specific variables</li>
                    <li>Secure state management</li>
                    <li>VCS integration & triggers</li>
                    <li>Run triggers & automation</li>
                    <li>Policy as code enforcement</li>
                    <li>Audit trail & compliance</li>
                </ul>
            </div>
        </div>

        <div class="workspace-info">
            <h3>🔧 Multi-Workspace Architecture</h3>
            <p>This deployment demonstrates enterprise-grade workspace patterns:</p>
            <div class="code">
┌─ ${username}-terraform-lab Organization
│
├── 🟢 ${username}-dev-app-stack
│   ├── Auto Scaling: 1-2 instances (t3.micro)
│   ├── Network: Single AZ, basic encryption
│   └── Access: Developers (plan + apply)
│
├── 🟡 ${username}-staging-app-stack
│   ├── Auto Scaling: 1-4 instances (t3.small)
│   ├── Network: Multi-AZ, full encryption
│   └── Access: QA Team (plan + apply)
│
└── 🔴 ${username}-prod-app-stack
    ├── Auto Scaling: 2-8 instances (t3.medium)
    ├── Network: Multi-AZ, deletion protection
    └── Access: Operations (managed access)
            </div>
        </div>

        <?php
        // Display instance metadata
        $instance_id = @file_get_contents('http://169.254.169.254/latest/meta-data/instance-id');
        $az = @file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone');
        if ($instance_id): ?>
        <div class="workspace-info">
            <h3>📊 Instance Metadata</h3>
            <p><strong>Instance ID:</strong> <?= $instance_id ?></p>
            <p><strong>Availability Zone:</strong> <?= $az ?></p>
            <p><strong>Deployment Time:</strong> <?= date('Y-m-d H:i:s T') ?></p>
        </div>
        <?php endif; ?>
    </div>
</body>
</html>
HTML

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart apache to ensure everything is working
systemctl restart httpd
```

**outputs.tf:**
```hcl
output "workspace_architecture" {
  description = "Complete workspace architecture information"
  value = {
    workspace_metadata = local.workspace_metadata
    environment_config = local.current_config
    network_architecture = {
      vpc_id = aws_vpc.main.id
      vpc_cidr = var.vpc_cidr
      public_subnets = aws_subnet.public[*].id
      private_subnets = aws_subnet.private[*].id
      database_subnets = aws_subnet.database[*].id
      availability_zones = local.availability_zones
    }
    security_configuration = {
      alb_security_group = aws_security_group.alb.id
      app_security_group = aws_security_group.app_servers.id
      key_pair_name = aws_key_pair.app_key.key_name
    }
  }
}

output "application_endpoints" {
  description = "Application access points and health checks"
  value = {
    load_balancer_dns = aws_lb.main.dns_name
    load_balancer_zone_id = aws_lb.main.zone_id
    application_url = "http://${aws_lb.main.dns_name}"
    health_check_url = "http://${aws_lb.main.dns_name}/health"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "storage_resources" {
  description = "S3 buckets and storage configuration"
  value = {
    data_bucket = {
      name = aws_s3_bucket.app_data.id
      arn = aws_s3_bucket.app_data.arn
      versioning = aws_s3_bucket_versioning.app_data.versioning_configuration[0].status
    }
    logs_bucket = {
      name = aws_s3_bucket.app_logs.id
      arn = aws_s3_bucket.app_logs.arn
      lifecycle_rules = "enabled"
    }
    backups_bucket = {
      name = aws_s3_bucket.app_backups.id
      arn = aws_s3_bucket.app_backups.arn
    }
  }
}

output "auto_scaling_configuration" {
  description = "Auto Scaling Group and Launch Template details"
  value = {
    asg_name = aws_autoscaling_group.app.name
    asg_arn = aws_autoscaling_group.app.arn
    launch_template_id = aws_launch_template.app.id
    launch_template_version = aws_launch_template.app.latest_version
    capacity_configuration = {
      min_size = local.current_config.min_size
      max_size = local.current_config.max_size
      desired_capacity = local.current_config.desired_capacity
      instance_type = local.current_config.instance_type
    }
    scaling_policies = {
      scale_up = aws_autoscaling_policy.scale_up.name
      scale_down = aws_autoscaling_policy.scale_down.name
    }
  }
}

output "terraform_cloud_enterprise_features" {
  description = "Advanced Terraform Cloud capabilities demonstrated"
  value = {
    workspace_features = [
      "Advanced variable validation and typing",
      "Environment-specific resource sizing",
      "Multi-tier network architecture",
      "Auto Scaling with policies",
      "Application Load Balancer integration",
      "S3 lifecycle management",
      "IAM role-based security",
      "CloudWatch monitoring integration",
      "Health check automation",
      "Multi-AZ deployment patterns"
    ]
    team_collaboration = [
      "Role-based access control (RBAC)",
      "Environment-specific team permissions",
      "Workspace tagging and organization",
      "Secure variable management",
      "Audit trail and compliance logging",
      "Detailed run logs per workspace",
      "Policy as code enforcement",
      "VCS integration with triggers",
      "Cross-workspace data sharing",
      "Automated testing and validation"
    ]
    governance_benefits = [
      "Workspace isolation prevents environment conflicts",
      "Variable inheritance reduces configuration drift",
      "Tag-based cost allocation and reporting",
      "Compliance validation before deployment",
      "Automated backup and disaster recovery",
      "Security scanning and vulnerability assessment",
      "Performance monitoring and alerting",
      "Resource lifecycle management"
    ]
  }
}

output "workspace_urls_and_commands" {
  description = "Helpful URLs and commands for workspace management"
  value = {
    workspace_url = "https://app.terraform.io/app/${terraform.workspace}/workspaces"
    terraform_commands = {
      init = "terraform init"
      plan = "terraform plan -var='environment=${var.environment}'"
      apply = "terraform apply -var='environment=${var.environment}'"
      destroy = "terraform destroy -var='environment=${var.environment}'"
    }
    aws_commands = {
      list_instances = "aws ec2 describe-instances --filters 'Name=tag:Environment,Values=${var.environment}'"
      list_s3_buckets = "aws s3 ls | grep ${var.username}-${var.environment}"
      check_asg = "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.app.name}"
    }
  }
}
```

### Step 3: Initialize and Deploy Advanced Infrastructure
```bash
# Initialize with advanced workspace configuration
terraform init

# Validate configuration with advanced validation
terraform validate

# Plan deployment with detailed output
terraform plan -var="username=$TF_VAR_username" -var="environment=dev" -var="vpc_cidr=10.1.0.0/16" -var="enable_monitoring=false"

# Apply with workspace-specific variables
terraform apply -var="username=$TF_VAR_username" -var="environment=dev" -var="vpc_cidr=10.1.0.0/16" -var="enable_monitoring=false"
```

---

## 🌍 **Exercise 10.2: Advanced Multi-Workspace Architecture (20 minutes)**

### Step 1: Create Production-Ready Staging Workspace
1. Go to your Terraform Cloud organization
2. Click "New workspace"
3. Choose "CLI-driven workflow"
4. Workspace name: `${your-username}-staging-app-stack` (e.g., `user1-staging-app-stack`)
5. Add description: "Staging environment for application stack with advanced features"
6. Add tags: `environment:staging`, `stack:application`, `team:qa`
7. Click "Create workspace"

### Step 2: Configure Advanced Workspace Variables
In the staging workspace, configure comprehensive variables:

**Environment Variables (mark as sensitive):**
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_DEFAULT_REGION`: "us-east-2"

**Terraform Variables:**
- `username`: Your username (e.g., "user1")
- `environment`: "staging"
- `application_name`: "webapp"
- `vpc_cidr`: "10.2.0.0/16" (different from dev)
- `enable_monitoring`: true
- `backup_retention_days`: 14
- `team_access`: 
  ```json
  {
    "developers": ["dev-team@company.com"],
    "operations": ["ops-team@company.com"],
    "readonly": ["stakeholders@company.com"]
  }
  ```

### Step 3: Create Staging Configuration with Advanced Settings
Create a new directory and configuration for staging:

```bash
# Create staging configuration
mkdir ../terraform-lab10-staging
cd ../terraform-lab10-staging

# Copy configuration files
cp ../terraform-lab10/main.tf .
cp ../terraform-lab10/outputs.tf .
cp ../terraform-lab10/user_data.sh .
```

Edit **main.tf** for staging workspace:
```hcl
terraform {
  # ... keep all existing config ...
  cloud {
    organization = "user1-terraform-lab"  # Replace user1 with your username!
    
    workspaces {
      name = "user1-staging-app-stack"  # Replace user1 with your username!
      tags = ["environment:staging", "stack:application", "owner:${var.username}"]
    }
  }
}
```

**Add workspace-specific settings file (workspace-staging.tfvars):**
```hcl
# Staging-specific configuration
username = "user1"  # Replace with your username
environment = "staging"
application_name = "webapp"
vpc_cidr = "10.2.0.0/16"
enable_monitoring = true
backup_retention_days = 14

# Staging team access configuration
team_access = {
  developers = ["dev-team@company.com"]
  operations = ["ops-team@company.com"]
  readonly   = ["qa-team@company.com", "stakeholders@company.com"]
}
```

### Step 4: Deploy Advanced Staging Environment
```bash
# Initialize staging workspace
terraform init

# Plan with staging-specific variables
terraform plan -var-file="workspace-staging.tfvars"

# Apply staging configuration
terraform apply -var-file="workspace-staging.tfvars"

# Verify staging deployment
echo "Staging deployment complete!"
echo "Application URL: $(terraform output -raw application_endpoints | jq -r '.application_url')"
echo "Health Check: $(terraform output -raw application_endpoints | jq -r '.health_check_url')"
```

### Step 5: Create Production Workspace with Enhanced Security
Create a production workspace with advanced governance:

1. **Create workspace**: `${your-username}-prod-app-stack`
2. **Configure advanced settings:**
   - Enable "Auto apply" = false (require manual approval)
   - Set "Terraform version" = "1.5.x" (pin version for stability)
   - Add tags: `environment:prod`, `compliance:high`, `criticality:high`
3. **Production variables:**
   ```
   environment = "prod"
   vpc_cidr = "10.3.0.0/16" 
   enable_monitoring = true
   backup_retention_days = 90
   ```
4. **Enable workspace notifications** for production deployments
5. **Configure run triggers** from staging workspace (optional)

---

## 👥 **Exercise 10.3: Advanced Team Management and Governance (20 minutes)**

### Step 1: Implement Enterprise Team Structure
Create a comprehensive team management structure:

1. **Go to "Settings" → "Teams"**
2. **Create multiple teams with specific roles:**
   - Team: `${your-username}-developers`
     - Purpose: Development environment access
     - Permissions: Plan and apply to dev workspaces
   - Team: `${your-username}-qa-engineers` 
     - Purpose: Staging environment management
     - Permissions: Plan and apply to staging
   - Team: `${your-username}-sre-ops`
     - Purpose: Production operations
     - Permissions: All production workspace access
   - Team: `${your-username}-security-auditors`
     - Purpose: Cross-environment compliance
     - Permissions: Read-only access to all workspaces
3. **Configure team organization settings**

### Step 2: Configure Advanced Workspace Access Control
Implement role-based access control (RBAC) across workspaces:

1. **For each workspace, configure team access:**

   **Development Workspace (`user1-dev-app-stack`):**
   - `user1-developers`: **Write** (plan + apply)
   - `user1-qa-engineers`: **Read** (monitoring only)
   - `user1-sre-ops`: **Read** (oversight)
   - `user1-security-auditors`: **Read** (compliance)

   **Staging Workspace (`user1-staging-app-stack`):**
   - `user1-developers`: **Plan** (can plan, but not apply)
   - `user1-qa-engineers`: **Write** (plan + apply)
   - `user1-sre-ops`: **Write** (full access)
   - `user1-security-auditors`: **Read** (compliance)

   **Production Workspace (`user1-prod-app-stack`):**
   - `user1-developers`: **Read** (monitoring only)
   - `user1-qa-engineers`: **Read** (validation)
   - `user1-sre-ops`: **Admin** (full management)
   - `user1-security-auditors`: **Read** (compliance)

2. **Configure workspace-specific settings:**
   - Enable **approval workflows** for production
   - Set **required approvers** (minimum 2 for prod)
   - Configure **run triggers** between environments
   - Configure **run triggers** for workspace automation

### Step 3: Simulate Team Collaboration
Even though you're working alone, let's understand how teams would work:

**Scenario**: You're setting up access for different team roles

1. **Developers**: Can plan and apply to dev environment
2. **QA Team**: Can read staging environment, plan but not apply
3. **Operations**: Full access to production environment

Create a simple access control document:

**team-access.md:**
```markdown
# Team Access Control - Lab 10

## Environment Access Matrix

| Team | Dev Workspace | Staging Workspace | Prod Workspace |
|------|---------------|-------------------|----------------|
| Developers | Plan + Apply | Read only | Read only |
| QA Team | Read only | Plan + Apply | Read only |  
| Operations | Read only | Plan + Apply | Plan + Apply |
| Security | Read all | Read all | Read all |

## Benefits of Terraform Cloud Team Management:
- ✅ Role-based access control
- ✅ Environment-specific permissions  
- ✅ Audit trail of who made changes
- ✅ Approval workflows for production
- ✅ Secure credential sharing

## Workspace Variables:
- Environment variables (AWS credentials) shared securely
- Terraform variables unique per environment
- Sensitive values encrypted and masked
```

```bash
# Save this understanding
cat > team-access.md << 'EOF'
# Team Access Control - Lab 10

## Environment Access Matrix

| Team | Dev Workspace | Staging Workspace | Prod Workspace |
|------|---------------|-------------------|----------------|
| Developers | Plan + Apply | Read only | Read only |
| QA Team | Read only | Plan + Apply | Read only |  
| Operations | Read only | Plan + Apply | Plan + Apply |
| Security | Read all | Read all | Read all |

## Benefits of Terraform Cloud Team Management:
- ✅ Role-based access control
- ✅ Environment-specific permissions  
- ✅ Audit trail of who made changes
- ✅ Approval workflows for production
- ✅ Secure credential sharing

## Workspace Variables:
- Environment variables (AWS credentials) shared securely
- Terraform variables unique per environment
- Sensitive values encrypted and masked
EOF
```

---

## 🎉 **Lab Summary**

### What You Accomplished:
✅ **Created multiple workspaces** for different environments  
✅ **Used workspace-specific variables** for environment configuration  
✅ **Deployed same configuration** with different settings per workspace  
✅ **Learned team management basics** in Terraform Cloud  
✅ **Understood workspace access control** concepts  
✅ **Experienced environment isolation** with separate state files  

### Workspaces You Created:
1. **Dev Environment**: t2.micro, no versioning, basic monitoring
2. **Staging Environment**: t2.small, versioning enabled, basic monitoring  
3. **Production Environment**: t2.medium, versioning enabled, full monitoring

### Team Collaboration Benefits:
- **Workspace Isolation**: Each environment has separate state and access
- **Role-Based Access**: Control who can do what in each environment
- **Secure Variables**: Credentials shared securely across team
- **Audit Trail**: Track all changes and who made them
- **Approval Workflows**: Require approvals for critical changes

---

## 🔍 **Understanding Workspace Management**

### Why Multiple Workspaces?
✅ **Environment Isolation**: Keep dev, staging, and prod completely separate  
✅ **Different Settings**: Each environment can have unique configurations  
✅ **Team Access Control**: Developers get dev access, ops get prod access  
✅ **Risk Management**: Test in dev, validate in staging, deploy to prod safely  
✅ **State Isolation**: No risk of environment state conflicts  

### Workspace vs Environment Comparison:

| Aspect | Single Workspace | Multiple Workspaces |
|--------|------------------|---------------------|
| **State Management** | Shared state | Isolated state per environment |
| **Risk** | Changes affect all environments | Changes isolated to one environment |
| **Team Access** | All-or-nothing | Granular per environment |
| **Variables** | Shared variables | Environment-specific variables |
| **Best Practice** | Good for learning | Production-ready approach |

### Your Multi-Workspace Architecture:
```
Terraform Cloud Organization
├── 🟢 user1-dev-environment
│   ├── State: isolated
│   ├── Variables: development settings
│   └── Access: developers
├── 🟡 user1-staging-environment  
│   ├── State: isolated
│   ├── Variables: staging settings
│   └── Access: QA team
└── 🔴 user1-prod-environment
    ├── State: isolated
    ├── Variables: production settings
    └── Access: operations team
```

---

## 🔄 **Exercise 10.4: Compare Environments (Optional)**

If you have extra time, compare your environments:

```bash
# Check what's deployed in each environment
echo "=== DEVELOPMENT ==="
# Visit dev instance URL

echo "=== STAGING ==="  
# Visit staging instance URL

echo "=== PRODUCTION ==="
# Visit production instance URL

# Compare S3 buckets
aws s3 ls | grep ${TF_VAR_username}
```

You should see different:
- Instance sizes
- Bucket versioning settings
- Monitoring configurations

---

## 🧹 **Clean Up**

```bash
# Clean up each environment
# (You'll need to do this in each workspace directory)

# Dev environment
cd terraform-lab10
terraform destroy

# Staging environment  
cd ../terraform-lab10-staging
terraform destroy

# Production environment
cd ../terraform-lab10-prod
terraform destroy
```

---

## ❓ **Troubleshooting**

### Problem: "Workspace not found"
**Solution**: Make sure you created the workspace in Terraform Cloud first.

### Problem: "Variables not set"
**Solution**: Set both AWS credentials and terraform variables in each workspace.

### Problem: "State conflicts"
**Solution**: Each workspace has isolated state - this shouldn't happen with proper workspace setup.

### Problem: "Can't access workspace"
**Solution**: Check team membership and workspace access permissions.

---

## 🎯 **Next Steps**

In Lab 11, you'll learn:
- Basic policy concepts in Terraform Cloud
- Working with the private registry
- Simple compliance and governance

**Fantastic! You now understand how to manage multiple environments with Terraform Cloud! 🚀**

## 📝 **Workspace Management Cheat Sheet**

### Key Concepts:
```bash
# Each workspace has:
- Isolated Terraform state
- Separate environment variables  
- Independent access controls
- Unique run history
- Environment-specific settings
```

### Workspace Organization Best Practices:
- **Naming**: `{username}-{environment}-{purpose}`
- **Variables**: Environment-specific values per workspace
- **Access**: Minimum required permissions per team
- **State**: Never share state between environments
- **Variables**: Use workspace variables, not hard-coded values

### Team Access Levels:
- **Read**: View workspace and runs
- **Plan**: Create plans (but not apply)
- **Write**: Plan and apply changes
- **Admin**: Full workspace management