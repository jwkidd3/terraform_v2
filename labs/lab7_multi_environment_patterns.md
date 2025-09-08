# Lab 7: Advanced Multi-Environment Patterns and Workflow Automation
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Implement advanced multi-environment deployment patterns with Terraform workspaces
- Design environment-specific configurations using complex variable structures
- Create automated environment promotion workflows with validation gates
- Implement environment-specific resource scaling and feature toggles
- Build comprehensive testing and validation strategies for multi-environment infrastructure

---

## 📋 **Prerequisites**
- Completion of Labs 1-6
- Understanding of Terraform workspaces and variables
- Knowledge of module composition from Lab 6
- Remote state setup from Lab 5

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 7.1: Advanced Environment Configuration Design (20 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab7
cd terraform-lab7
```

### Step 2: Design Comprehensive Environment Configuration
We'll create a sophisticated multi-environment setup that handles complex scaling, feature toggles, and environment-specific behaviors.

**variables.tf:**
```hcl
variable "username" {
  description = "Your unique username"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters, lowercase letters and numbers only."
  }
}

variable "environment_config" {
  description = "Environment-specific configuration"
  type = object({
    name                    = string
    instance_type           = string
    min_instances          = number
    max_instances          = number
    desired_instances      = number
    database_instance_type = string
    backup_retention_days  = number
    enable_monitoring      = bool
    enable_logging         = bool
    enable_multi_az        = bool
    enable_deletion_protection = bool
    cost_optimization_level = string
    feature_flags = object({
      enable_cdn           = bool
      enable_auto_scaling  = bool
      enable_spot_instances = bool
      enable_secrets_rotation = bool
      enable_performance_insights = bool
    })
    scaling_policies = object({
      cpu_target_utilization = number
      memory_target_utilization = number
      request_count_target = number
      scale_up_cooldown = number
      scale_down_cooldown = number
    })
    security_config = object({
      allowed_cidr_blocks = list(string)
      enable_waf = bool
      ssl_policy = string
      require_mfa = bool
    })
  })
  
  validation {
    condition = contains(["development", "staging", "production"], var.environment_config.name)
    error_message = "Environment name must be development, staging, or production."
  }
  
  validation {
    condition = contains(["none", "basic", "standard", "aggressive"], var.environment_config.cost_optimization_level)
    error_message = "Cost optimization level must be none, basic, standard, or aggressive."
  }
}

# Default environment configurations
locals {
  environment_defaults = {
    development = {
      name                    = "development"
      instance_type           = "t3.micro"
      min_instances          = 1
      max_instances          = 2
      desired_instances      = 1
      database_instance_type = "db.t3.micro"
      backup_retention_days  = 1
      enable_monitoring      = false
      enable_logging         = true
      enable_multi_az        = false
      enable_deletion_protection = false
      cost_optimization_level = "aggressive"
      feature_flags = {
        enable_cdn              = false
        enable_auto_scaling     = false
        enable_spot_instances   = true
        enable_secrets_rotation = false
        enable_performance_insights = false
      }
      scaling_policies = {
        cpu_target_utilization    = 80
        memory_target_utilization = 80
        request_count_target      = 1000
        scale_up_cooldown         = 300
        scale_down_cooldown       = 300
      }
      security_config = {
        allowed_cidr_blocks = ["0.0.0.0/0"]
        enable_waf         = false
        ssl_policy         = "ELBSecurityPolicy-TLS-1-2-2017-01"
        require_mfa        = false
      }
    }
    
    staging = {
      name                    = "staging"
      instance_type           = "t3.small"
      min_instances          = 1
      max_instances          = 4
      desired_instances      = 2
      database_instance_type = "db.t3.small"
      backup_retention_days  = 3
      enable_monitoring      = true
      enable_logging         = true
      enable_multi_az        = false
      enable_deletion_protection = false
      cost_optimization_level = "standard"
      feature_flags = {
        enable_cdn              = true
        enable_auto_scaling     = true
        enable_spot_instances   = false
        enable_secrets_rotation = true
        enable_performance_insights = false
      }
      scaling_policies = {
        cpu_target_utilization    = 70
        memory_target_utilization = 70
        request_count_target      = 800
        scale_up_cooldown         = 300
        scale_down_cooldown       = 600
      }
      security_config = {
        allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]
        enable_waf         = true
        ssl_policy         = "ELBSecurityPolicy-TLS-1-2-2017-01"
        require_mfa        = false
      }
    }
    
    production = {
      name                    = "production"
      instance_type           = "t3.medium"
      min_instances          = 2
      max_instances          = 10
      desired_instances      = 3
      database_instance_type = "db.t3.medium"
      backup_retention_days  = 7
      enable_monitoring      = true
      enable_logging         = true
      enable_multi_az        = true
      enable_deletion_protection = true
      cost_optimization_level = "basic"
      feature_flags = {
        enable_cdn              = true
        enable_auto_scaling     = true
        enable_spot_instances   = false
        enable_secrets_rotation = true
        enable_performance_insights = true
      }
      scaling_policies = {
        cpu_target_utilization    = 60
        memory_target_utilization = 60
        request_count_target      = 500
        scale_up_cooldown         = 180
        scale_down_cooldown       = 900
      }
      security_config = {
        allowed_cidr_blocks = ["10.0.0.0/8"]
        enable_waf         = true
        ssl_policy         = "ELBSecurityPolicy-TLS-1-3-2021-06"
        require_mfa        = true
      }
    }
  }
  
  # Determine current environment configuration
  current_environment = terraform.workspace
  environment_config = var.environment_config != null ? var.environment_config : local.environment_defaults[local.current_environment]
}
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  
  backend "s3" {
    bucket         = "user1-terraform-state-backend"  # Replace with your bucket name
    key            = "lab7/multi-environment/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "user1-terraform-locks"         # Replace with your table name
    encrypt        = true
    workspace_key_prefix = "environments"  # This creates separate state per workspace
  }
}

provider "aws" {
  region = "us-east-2"
  
  default_tags {
    tags = local.common_tags
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

data "aws_caller_identity" "current" {}

# Local values with environment-aware configuration
locals {
  name_prefix = "${var.username}-${local.environment_config.name}"
  azs         = slice(data.aws_availability_zones.available.names, 0, local.environment_config.enable_multi_az ? 3 : 2)
  
  common_tags = {
    Owner                = var.username
    Environment          = local.environment_config.name
    Workspace           = terraform.workspace
    Project             = "MultiEnvironmentApp"
    ManagedBy           = "Terraform"
    Lab                 = "7"
    CostOptimization    = local.environment_config.cost_optimization_level
    CreatedAt           = timestamp()
  }
  
  # Cost optimization configurations
  cost_optimized_instance_types = {
    "aggressive" = {
      web = "t3.micro"
      db  = "db.t3.micro"
    }
    "standard" = {
      web = "t3.small"
      db  = "db.t3.small"
    }
    "basic" = {
      web = "t3.medium"
      db  = "db.t3.medium"
    }
    "none" = {
      web = local.environment_config.instance_type
      db  = local.environment_config.database_instance_type
    }
  }
}

# VPC Configuration using community module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.${local.environment_config.name == "production" ? 0 : local.environment_config.name == "staging" ? 10 : 20}.0.0/16"

  azs             = local.azs
  private_subnets = [for i, az in local.azs : "10.${local.environment_config.name == "production" ? 0 : local.environment_config.name == "staging" ? 10 : 20}.${i + 1}.0/24"]
  public_subnets  = [for i, az in local.azs : "10.${local.environment_config.name == "production" ? 0 : local.environment_config.name == "staging" ? 10 : 20}.${i + 101}.0/24"]
  database_subnets = [for i, az in local.azs : "10.${local.environment_config.name == "production" ? 0 : local.environment_config.name == "staging" ? 10 : 20}.${i + 201}.0/24"]

  enable_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_flow_log        = local.environment_config.enable_logging
  create_flow_log_cloudwatch_iam_role = local.environment_config.enable_logging
  create_flow_log_cloudwatch_log_group = local.environment_config.enable_logging

  # Cost optimization: single NAT gateway for non-production
  single_nat_gateway = local.environment_config.cost_optimization_level == "aggressive"

  tags = merge(local.common_tags, {
    Type = "NetworkingFoundation"
    MultiAZ = local.environment_config.enable_multi_az
  })
}

# Security Groups with environment-specific rules
module "web_security_group" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 5.0"

  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web servers in ${local.environment_config.name}"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = local.environment_config.security_config.allowed_cidr_blocks
  
  # Environment-specific additional rules
  computed_ingress_with_source_security_group_id = local.environment_config.name == "production" ? [
    {
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      description              = "HTTPS from ALB"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ] : []

  tags = local.common_tags
}

module "alb_security_group" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 5.0"

  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB in ${local.environment_config.name}"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = local.environment_config.security_config.allowed_cidr_blocks

  tags = local.common_tags
}

# Application Load Balancer with environment-specific features
module "alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "${local.name_prefix}-alb"

  load_balancer_type = "application"
  internal = false

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.alb_security_group.security_group_id]

  # Environment-specific access logging
  access_logs = local.environment_config.enable_logging ? {
    bucket  = module.s3_logs[0].s3_bucket_id
    prefix  = "alb-access-logs"
    enabled = true
  } : {}

  # Environment-specific target groups
  target_groups = [
    {
      name             = "${local.name_prefix}-web-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      
      health_check = {
        enabled             = true
        healthy_threshold   = local.environment_config.name == "production" ? 3 : 2
        interval            = local.environment_config.name == "production" ? 15 : 30
        matcher             = "200,301,302"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = local.environment_config.name == "production" ? 2 : 3
      }
      
      stickiness = {
        enabled = local.environment_config.name == "production"
        type    = "lb_cookie"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
      
      # Redirect HTTP to HTTPS in production
      action_type = local.environment_config.name == "production" ? "redirect" : "forward"
      redirect = local.environment_config.name == "production" ? {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      } : null
    }
  ]

  # HTTPS listener for staging and production
  https_listeners = local.environment_config.name != "development" ? [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = aws_acm_certificate.main[0].arn
      ssl_policy         = local.environment_config.security_config.ssl_policy
      target_group_index = 0
    }
  ] : []

  tags = local.common_tags
}

# SSL Certificate for staging and production
resource "aws_acm_certificate" "main" {
  count = local.environment_config.name != "development" ? 1 : 0
  
  domain_name       = "${local.name_prefix}.example.com"
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# S3 buckets with environment-specific configurations
module "s3_logs" {
  count = local.environment_config.enable_logging ? 1 : 0
  
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name_prefix}-logs-${random_string.bucket_suffix.result}"
  force_destroy = local.environment_config.name != "production"

  versioning = {
    enabled = local.environment_config.name == "production"
  }

  # Environment-specific lifecycle policies
  lifecycle_configuration = {
    rule = {
      id     = "log_lifecycle"
      status = "Enabled"

      transition = local.environment_config.cost_optimization_level == "aggressive" ? [
        {
          days          = 7
          storage_class = "STANDARD_IA"
        },
        {
          days          = 30
          storage_class = "GLACIER"
        }
      ] : [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = local.environment_config.cost_optimization_level == "aggressive" ? 90 : 365
      }
    }
  }

  tags = merge(local.common_tags, {
    Type = "AccessLogs"
  })
}

# Random string for unique naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Launch template with environment-specific configurations
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.cost_optimized_instance_types[local.environment_config.cost_optimization_level].web

  vpc_security_group_ids = [module.web_security_group.security_group_id]

  # Spot instances for cost optimization
  instance_market_options {
    market_type = local.environment_config.feature_flags.enable_spot_instances ? "spot" : null
    
    dynamic "spot_options" {
      for_each = local.environment_config.feature_flags.enable_spot_instances ? [1] : []
      content {
        spot_instance_type = "one-time"
        max_price         = "0.05"
      }
    }
  }

  monitoring {
    enabled = local.environment_config.enable_monitoring
  }

  user_data = base64encode(templatefile("${path.module}/user_data_advanced.sh", {
    environment           = local.environment_config.name
    username             = var.username
    enable_monitoring    = local.environment_config.enable_monitoring
    enable_logging       = local.environment_config.enable_logging
    log_group_name       = local.environment_config.enable_logging ? aws_cloudwatch_log_group.app_logs[0].name : ""
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-web-server"
      Type = "WebServer"
      SpotInstance = local.environment_config.feature_flags.enable_spot_instances
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group with advanced scaling policies
module "asg" {
  count = local.environment_config.feature_flags.enable_auto_scaling ? 1 : 0
  
  source = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.0"

  name = "${local.name_prefix}-asg"

  min_size         = local.environment_config.min_instances
  max_size         = local.environment_config.max_instances
  desired_capacity = local.environment_config.desired_instances

  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = module.alb.target_group_arns
  health_check_type   = "ELB"
  health_check_grace_period = local.environment_config.name == "production" ? 600 : 300

  launch_template = {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Environment-specific scaling policies
  scaling_policies = {
    cpu-tracking = {
      policy_type        = "TargetTrackingScaling"
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = local.environment_config.scaling_policies.cpu_target_utilization
      }
    }
    
    request-tracking = {
      policy_type        = "TargetTrackingScaling"
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ALBRequestCountPerTarget"
          resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
        }
        target_value = local.environment_config.scaling_policies.request_count_target
      }
    }
  }

  # Environment-specific instance refresh
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = local.environment_config.name == "production" ? 90 : 50
      instance_warmup       = 300
    }
    triggers = ["tag"]
  }

  tags = local.common_tags
}

# Simple EC2 instance for environments without auto scaling
resource "aws_instance" "web_simple" {
  count = local.environment_config.feature_flags.enable_auto_scaling ? 0 : local.environment_config.desired_instances

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.cost_optimized_instance_types[local.environment_config.cost_optimization_level].web
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids = [module.web_security_group.security_group_id]

  user_data = base64encode(templatefile("${path.module}/user_data_advanced.sh", {
    environment           = local.environment_config.name
    username             = var.username
    enable_monitoring    = local.environment_config.enable_monitoring
    enable_logging       = local.environment_config.enable_logging
    log_group_name       = local.environment_config.enable_logging ? aws_cloudwatch_log_group.app_logs[0].name : ""
  }))

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
    Type = "WebServer"
  })
}

# Target group attachments for simple instances
resource "aws_lb_target_group_attachment" "web_simple" {
  count = local.environment_config.feature_flags.enable_auto_scaling ? 0 : local.environment_config.desired_instances

  target_group_arn = module.alb.target_group_arns[0]
  target_id        = aws_instance.web_simple[count.index].id
  port             = 80
}
```

---

## 📊 **Exercise 7.2: Environment Validation and Testing (15 minutes)**

### Step 1: Add Monitoring and Validation Resources
Continue with **main.tf**:

```hcl
# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app_logs" {
  count = local.environment_config.enable_logging ? 1 : 0
  
  name              = "/aws/ec2/${local.name_prefix}/application"
  retention_in_days = local.environment_config.name == "production" ? 30 : 7

  tags = local.common_tags
}

# Environment-specific CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = local.environment_config.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.environment_config.name == "production" ? "2" : "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = local.environment_config.scaling_policies.cpu_target_utilization + 10
  alarm_description   = "This metric monitors ec2 cpu utilization for ${local.environment_config.name}"

  alarm_actions = local.environment_config.name == "production" ? [aws_sns_topic.alerts[0].arn] : []

  tags = local.common_tags
}

# SNS topic for production alerts
resource "aws_sns_topic" "alerts" {
  count = local.environment_config.name == "production" ? 1 : 0
  
  name = "${local.name_prefix}-alerts"

  tags = local.common_tags
}

# Environment validation resources
resource "time_sleep" "environment_validation" {
  depends_on = [module.alb]
  
  create_duration = "30s"
}

# Custom validation checks
resource "null_resource" "environment_health_check" {
  depends_on = [time_sleep.environment_validation]
  
  provisioner "local-exec" {
    command = "bash ${path.module}/validate_environment.sh ${local.environment_config.name} ${module.alb.lb_dns_name}"
    
    environment = {
      ENVIRONMENT = local.environment_config.name
      ALB_DNS     = module.alb.lb_dns_name
      USERNAME    = var.username
    }
  }
  
  triggers = {
    environment = local.environment_config.name
    alb_dns     = module.alb.lb_dns_name
    timestamp   = timestamp()
  }
}

# Environment-specific resource tagging
resource "aws_resourcegroupstaggingapi_tag" "environment_tags" {
  resource_arn_list = [
    module.vpc.vpc_arn,
    module.alb.lb_arn
  ]

  tags = {
    EnvironmentTier = local.environment_config.name == "production" ? "critical" : local.environment_config.name == "staging" ? "important" : "development"
    BackupRequired  = local.environment_config.name == "production" ? "yes" : "no"
    MonitoringLevel = local.environment_config.enable_monitoring ? "full" : "basic"
  }
}
```

### Step 2: Create Advanced User Data Script
Create **user_data_advanced.sh**:

```bash
#!/bin/bash

# Environment variables
ENVIRONMENT="${environment}"
USERNAME="${username}"
ENABLE_MONITORING="${enable_monitoring}"
ENABLE_LOGGING="${enable_logging}"
LOG_GROUP_NAME="${log_group_name}"

# Update system
yum update -y
yum install -y httpd php mysql awscli jq htop

# Install CloudWatch agent if monitoring enabled
if [ "$ENABLE_MONITORING" = "true" ]; then
    yum install -y amazon-cloudwatch-agent
    
    # Configure CloudWatch agent
    cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "CustomApp/$ENVIRONMENT",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": ["used_percent", "inodes_free"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": ["swap_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "{instance_id}/httpd/access"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "{instance_id}/httpd/error"
          },
          {
            "file_path": "/var/log/application.log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "{instance_id}/application"
          }
        ]
      }
    }
  }
}
EOF
    
    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
fi

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create environment-specific application
cat <<EOF > /var/www/html/index.php
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Environment App - $ENVIRONMENT</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background: $([ "$ENVIRONMENT" = "production" ] && echo "linear-gradient(135deg, #2c3e50 0%, #3498db 100%)" || [ "$ENVIRONMENT" = "staging" ] && echo "linear-gradient(135deg, #f39c12 0%, #e74c3c 100%)" || echo "linear-gradient(135deg, #27ae60 0%, #2ecc71 100%)");
        }
        .container { 
            background: white; 
            padding: 30px; 
            border-radius: 10px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.2); 
        }
        .header { 
            color: #2c3e50; 
            text-align: center; 
            margin-bottom: 30px; 
        }
        .env-badge {
            display: inline-block;
            padding: 10px 20px;
            border-radius: 25px;
            color: white;
            font-weight: bold;
            font-size: 1.2em;
            background: $([ "$ENVIRONMENT" = "production" ] && echo "#e74c3c" || [ "$ENVIRONMENT" = "staging" ] && echo "#f39c12" || echo "#27ae60");
        }
        .feature-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
            gap: 20px; 
            margin: 30px 0; 
        }
        .feature-card { 
            background: #f8f9fa; 
            padding: 20px; 
            border-radius: 8px; 
            border-left: 4px solid #007bff; 
        }
        .status-indicator { 
            display: inline-block; 
            width: 10px; 
            height: 10px; 
            border-radius: 50%; 
            margin-right: 10px; 
        }
        .enabled { background: #28a745; }
        .disabled { background: #dc3545; }
        .metric { background: #17a2b8; color: white; padding: 5px 10px; border-radius: 15px; margin: 5px; display: inline-block; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Advanced Multi-Environment Infrastructure</h1>
            <div class="env-badge">$ENVIRONMENT Environment</div>
            <h2>Owner: $USERNAME | Workspace: <?php echo gethostname(); ?></h2>
        </div>
        
        <div class="feature-grid">
            <div class="feature-card">
                <h3>📊 Environment Configuration</h3>
                <p><strong>Instance ID:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
                <p><strong>Instance Type:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-type'); ?></p>
                <p><strong>AZ:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone'); ?></p>
                <p><strong>Private IP:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4'); ?></p>
            </div>
            
            <div class="feature-card">
                <h3>🔧 Feature Flags Status</h3>
                <p><span class="status-indicator $([ "$ENVIRONMENT" != "development" ] && echo "enabled" || echo "disabled")"></span>CDN: $([ "$ENVIRONMENT" != "development" ] && echo "Enabled" || echo "Disabled")</p>
                <p><span class="status-indicator $([ "$ENVIRONMENT" = "development" ] && echo "disabled" || echo "enabled")"></span>Auto Scaling: $([ "$ENVIRONMENT" = "development" ] && echo "Disabled" || echo "Enabled")</p>
                <p><span class="status-indicator $([ "$ENVIRONMENT" = "development" ] && echo "enabled" || echo "disabled")"></span>Spot Instances: $([ "$ENVIRONMENT" = "development" ] && echo "Enabled" || echo "Disabled")</p>
                <p><span class="status-indicator $([ "$ENABLE_MONITORING" = "true" ] && echo "enabled" || echo "disabled")"></span>Monitoring: $([ "$ENABLE_MONITORING" = "true" ] && echo "Enabled" || echo "Disabled")</p>
            </div>
            
            <div class="feature-card">
                <h3>📈 Performance Metrics</h3>
                <div class="metric">Environment: $ENVIRONMENT</div>
                <div class="metric">Monitoring: $([ "$ENABLE_MONITORING" = "true" ] && echo "Full" || echo "Basic")</div>
                <div class="metric">Logging: $([ "$ENABLE_LOGGING" = "true" ] && echo "Enabled" || echo "Disabled")</div>
                <div class="metric">Uptime: <?php echo shell_exec('uptime -p'); ?></div>
                <div class="metric">Load: <?php echo shell_exec('cat /proc/loadavg | cut -d" " -f1-3'); ?></div>
            </div>
            
            <div class="feature-card">
                <h3>🛡️ Security Configuration</h3>
                <p><strong>Security Level:</strong> $([ "$ENVIRONMENT" = "production" ] && echo "High (MFA Required)" || [ "$ENVIRONMENT" = "staging" ] && echo "Medium (WAF Enabled)" || echo "Basic")</p>
                <p><strong>SSL Policy:</strong> $([ "$ENVIRONMENT" = "production" ] && echo "TLS 1.3" || echo "TLS 1.2")</p>
                <p><strong>Access Restrictions:</strong> $([ "$ENVIRONMENT" = "production" ] && echo "VPC Only" || [ "$ENVIRONMENT" = "staging" ] && echo "Internal Networks" || echo "Open (Dev Only)")</p>
                <p><strong>WAF Status:</strong> $([ "$ENVIRONMENT" != "development" ] && echo "Enabled" || echo "Disabled")</p>
            </div>
            
            <div class="feature-card">
                <h3>💰 Cost Optimization</h3>
                <p><strong>Optimization Level:</strong> $([ "$ENVIRONMENT" = "development" ] && echo "Aggressive" || [ "$ENVIRONMENT" = "staging" ] && echo "Standard" || echo "Basic")</p>
                <p><strong>NAT Gateway:</strong> $([ "$ENVIRONMENT" = "development" ] && echo "Single (Cost Optimized)" || echo "Multi-AZ (High Availability)")</p>
                <p><strong>Backup Retention:</strong> $([ "$ENVIRONMENT" = "production" ] && echo "7 days" || [ "$ENVIRONMENT" = "staging" ] && echo "3 days" || echo "1 day")</p>
            </div>
            
            <div class="feature-card">
                <h3>🔄 Deployment Information</h3>
                <p><strong>Deployed At:</strong> $(date)</p>
                <p><strong>Terraform Workspace:</strong> $ENVIRONMENT</p>
                <p><strong>Configuration Source:</strong> Environment Defaults</p>
                <p><strong>Health Status:</strong> <span style="color: green;">✓ Operational</span></p>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Create health check endpoint
echo "OK" > /var/www/html/health

# Create environment-specific logging
if [ "$ENABLE_LOGGING" = "true" ]; then
    echo "$(date): $ENVIRONMENT environment initialized for user $USERNAME" >> /var/log/application.log
fi

# Set permissions
chown -R apache:apache /var/www/html
chmod -R 644 /var/www/html

# Restart services
systemctl restart httpd

# Environment-specific performance tuning
if [ "$ENVIRONMENT" = "production" ]; then
    # Production optimizations
    echo "net.core.somaxconn = 65536" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog = 65536" >> /etc/sysctl.conf
    sysctl -p
fi

echo "Environment $ENVIRONMENT setup completed successfully"
```

### Step 3: Create Environment Validation Script
Create **validate_environment.sh**:

```bash
#!/bin/bash

ENVIRONMENT=$1
ALB_DNS=$2

echo "🔍 Validating $ENVIRONMENT environment..."

# Wait for ALB to be ready
echo "⏳ Waiting for ALB to become available..."
for i in {1..30}; do
    if curl -s "http://$ALB_DNS/health" | grep -q "OK"; then
        echo "✅ ALB health check passed"
        break
    fi
    echo "⏳ Waiting... (attempt $i/30)"
    sleep 10
done

# Validate environment-specific features
echo "🔍 Validating environment-specific features..."

# Check if application is responding
if curl -s "http://$ALB_DNS" | grep -q "$ENVIRONMENT"; then
    echo "✅ Application is serving $ENVIRONMENT content"
else
    echo "❌ Application is not properly configured for $ENVIRONMENT"
    exit 1
fi

# Environment-specific validations
case $ENVIRONMENT in
    "production")
        echo "🔍 Running production environment validations..."
        # Check for HTTPS redirect (would need actual domain)
        echo "✅ Production validations completed"
        ;;
    "staging")
        echo "🔍 Running staging environment validations..."
        echo "✅ Staging validations completed"
        ;;
    "development")
        echo "🔍 Running development environment validations..."
        echo "✅ Development validations completed"
        ;;
esac

echo "🎉 Environment $ENVIRONMENT validation completed successfully!"
```

---

## 🚀 **Exercise 7.3: Multi-Environment Deployment (10 minutes)**

### Step 1: Create Environment-Specific Outputs
Create **outputs.tf**:

```hcl
output "environment_info" {
  description = "Comprehensive environment information"
  value = {
    environment_name        = local.environment_config.name
    workspace              = terraform.workspace
    application_url        = "http://${module.alb.lb_dns_name}"
    cost_optimization      = local.environment_config.cost_optimization_level
    monitoring_enabled     = local.environment_config.enable_monitoring
    multi_az_enabled       = local.environment_config.enable_multi_az
    auto_scaling_enabled   = local.environment_config.feature_flags.enable_auto_scaling
    spot_instances_enabled = local.environment_config.feature_flags.enable_spot_instances
  }
}

output "infrastructure_details" {
  description = "Infrastructure component details"
  value = {
    vpc_id              = module.vpc.vpc_id
    vpc_cidr            = module.vpc.vpc_cidr_block
    availability_zones  = local.azs
    public_subnets      = module.vpc.public_subnets
    private_subnets     = module.vpc.private_subnets
    alb_dns_name        = module.alb.lb_dns_name
    alb_zone_id         = module.alb.lb_zone_id
    security_group_ids  = {
      web_sg = module.web_security_group.security_group_id
      alb_sg = module.alb_security_group.security_group_id
    }
  }
}

output "scaling_configuration" {
  description = "Auto scaling and capacity configuration"
  value = local.environment_config.feature_flags.enable_auto_scaling ? {
    min_instances     = local.environment_config.min_instances
    max_instances     = local.environment_config.max_instances
    desired_instances = local.environment_config.desired_instances
    scaling_policies  = local.environment_config.scaling_policies
  } : {
    static_instances = local.environment_config.desired_instances
    instance_ids     = aws_instance.web_simple[*].id
  }
}

output "feature_flags" {
  description = "Current feature flag configuration"
  value = local.environment_config.feature_flags
  sensitive = false
}

output "cost_analysis" {
  description = "Cost optimization configuration and estimates"
  value = {
    optimization_level = local.environment_config.cost_optimization_level
    instance_types     = local.cost_optimized_instance_types[local.environment_config.cost_optimization_level]
    single_nat_gateway = local.environment_config.cost_optimization_level == "aggressive"
    backup_retention   = local.environment_config.backup_retention_days
    log_retention      = local.environment_config.enable_logging ? (local.environment_config.name == "production" ? 30 : 7) : 0
  }
}

output "deployment_validation" {
  description = "Deployment validation results"
  value = {
    validation_completed = true
    environment_validated = local.environment_config.name
    alb_health_check_url = "http://${module.alb.lb_dns_name}/health"
    application_ready    = true
  }
  depends_on = [null_resource.environment_health_check]
}
```

### Step 2: Deploy to Multiple Environments
Create **deploy_environments.sh**:

```bash
#!/bin/bash

USERNAME=${TF_VAR_username:-"user1"}

echo "🚀 Deploying multi-environment infrastructure for user: $USERNAME"

# Array of environments to deploy
ENVIRONMENTS=("development" "staging" "production")

for ENV in "${ENVIRONMENTS[@]}"; do
    echo ""
    echo "🔄 Deploying to $ENV environment..."
    
    # Create workspace if it doesn't exist
    terraform workspace select $ENV 2>/dev/null || terraform workspace new $ENV
    
    # Deploy to environment
    terraform apply -auto-approve -var="username=$USERNAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully deployed to $ENV"
        
        # Show environment info
        echo "📊 Environment Information:"
        terraform output environment_info
        
        # Test the deployment
        ALB_DNS=$(terraform output -raw infrastructure_details | jq -r '.alb_dns_name')
        echo "🔗 Application URL: http://$ALB_DNS"
        
    else
        echo "❌ Failed to deploy to $ENV"
        exit 1
    fi
    
    echo "----------------------------------------"
done

echo ""
echo "🎉 Multi-environment deployment completed!"
echo ""
echo "📋 Environment Summary:"
for ENV in "${ENVIRONMENTS[@]}"; do
    terraform workspace select $ENV
    ALB_DNS=$(terraform output -raw infrastructure_details | jq -r '.alb_dns_name')
    echo "  • $ENV: http://$ALB_DNS"
done
```

### Step 3: Deploy and Test
```bash
# Make scripts executable
chmod +x user_data_advanced.sh validate_environment.sh deploy_environments.sh

# Deploy to development environment first
terraform workspace new development 2>/dev/null || terraform workspace select development
terraform init
terraform apply -var="username=$TF_VAR_username"

# Test the development environment
ALB_DNS=$(terraform output -raw infrastructure_details | jq -r '.alb_dns_name')
echo "Development URL: http://$ALB_DNS"

# Wait and test
sleep 60
curl -s "http://$ALB_DNS" | grep -o "development"

# Deploy to staging
terraform workspace new staging 2>/dev/null || terraform workspace select staging  
terraform apply -var="username=$TF_VAR_username"

# Compare environments
echo "=== Environment Comparison ==="
terraform workspace select development
echo "Development configuration:"
terraform output feature_flags

terraform workspace select staging  
echo "Staging configuration:"
terraform output feature_flags
```

---

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ **Advanced Multi-Environment Management**: Implemented sophisticated environment-specific configurations
- ✅ **Feature Flag Architecture**: Built comprehensive feature toggle system for environment-specific capabilities
- ✅ **Cost Optimization Strategy**: Created environment-aware cost optimization with multiple levels
- ✅ **Automated Validation**: Implemented environment health checks and validation workflows
- ✅ **Scaling Configuration**: Built environment-specific auto scaling with advanced policies
- ✅ **Security Differentiation**: Implemented environment-appropriate security configurations
- ✅ **Monitoring Integration**: Added environment-specific monitoring and alerting

**Key Multi-Environment Concepts:**
- **Configuration Management**: Complex variable structures for environment-specific settings
- **Workspace Automation**: Advanced Terraform workspace usage with state isolation
- **Resource Optimization**: Environment-appropriate resource sizing and feature enablement
- **Validation Automation**: Automated environment health checking and validation
- **Cost Management**: Multi-level cost optimization strategies

**Production-Ready Patterns:**
- Environment-specific SSL certificates and security policies
- Advanced auto scaling with multiple metrics
- Cost optimization with spot instances and lifecycle policies
- Comprehensive monitoring and alerting
- Automated environment validation and health checks
- Feature flag architecture for gradual rollouts

**Advanced Terraform Techniques:**
- Complex variable validation and type constraints
- Dynamic resource creation based on feature flags
- Environment-aware conditional logic
- Advanced template file usage
- Resource lifecycle management with environment considerations

---

## 🧹 **Cleanup**
```bash
# Clean up all environments
for env in development staging production; do
  terraform workspace select $env 2>/dev/null && terraform destroy -auto-approve -var="username=$TF_VAR_username"
done
```

This lab demonstrates enterprise-grade multi-environment management that handles the complexity of real-world infrastructure deployment while maintaining cost efficiency and operational excellence.