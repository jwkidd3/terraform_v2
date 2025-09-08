# Lab 6: Advanced Registry Modules and Module Composition
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Compose complex infrastructure using multiple Terraform Registry modules
- Implement advanced module patterns with conditional logic and dynamic blocks
- Integrate third-party modules with custom configurations
- Design module composition strategies for scalable infrastructure
- Handle module versioning and dependency management in production

---

## 📋 **Prerequisites**
- Completion of Labs 1-5
- Understanding of module basics from Lab 4
- Remote state setup from Lab 5
- Experience with VPC networking concepts

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 6.1: Multi-Module Infrastructure Design (20 minutes)**

### Step 1: Create Lab Directory
```bash
mkdir terraform-lab6
cd terraform-lab6
```

### Step 2: Design Complete Application Stack
We'll build a production-ready application stack using multiple registry modules combined with our custom components.

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
  }
  
  backend "s3" {
    bucket         = "user1-terraform-state-backend"  # Replace with your bucket name
    key            = "lab6/multi-module-app/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "user1-terraform-locks"         # Replace with your table name
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-2"
}

variable "username" {
  description = "Your unique username"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters, lowercase letters and numbers only."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "enable_monitoring" {
  description = "Enable comprehensive monitoring stack"
  type        = bool
  default     = true
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

# Local values for configuration
locals {
  name_prefix = "${var.username}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)
  
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    Project     = "MultiModuleApp"
    ManagedBy   = "Terraform"
    Lab         = "6"
  }
}

# VPC using community module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true

  # Cost optimization: single NAT gateway for development
  single_nat_gateway = var.environment != "production"

  tags = merge(local.common_tags, {
    Type = "NetworkingFoundation"
  })
}

# Security Groups using community module
module "web_security_group" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 5.0"

  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  # Additional SSH access from bastion
  ingress_with_source_security_group_id = [
    {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      description              = "SSH from bastion"
      source_security_group_id = module.bastion_security_group.security_group_id
    }
  ]

  tags = local.common_tags
}

module "bastion_security_group" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "~> 5.0"

  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.common_tags
}

module "rds_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      description              = "MySQL access from web servers"
      source_security_group_id = module.web_security_group.security_group_id
    }
  ]

  tags = local.common_tags
}

# Application Load Balancer using community module
module "alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "${local.name_prefix}-alb"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.alb_security_group.security_group_id]

  access_logs = {
    bucket = module.s3_logs.s3_bucket_id
    prefix = "alb-access-logs"
  }

  target_groups = [
    {
      name             = "${local.name_prefix}-web-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = local.common_tags
}

module "alb_security_group" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 5.0"

  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.common_tags
}

# S3 bucket for logs using community module
module "s3_logs" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name_prefix}-logs-${random_string.bucket_suffix.result}"

  # Bucket configuration
  force_destroy = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_configuration = {
    rule = {
      id     = "log_lifecycle"
      status = "Enabled"

      transition = [
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
        days = 365
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

# RDS using community module
module "rds" {
  source = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.name_prefix}-mysql"

  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.environment == "production" ? "db.t3.medium" : "db.t3.micro"
  allocated_storage = var.environment == "production" ? 100 : 20

  db_name  = "appdb"
  username = "admin"
  password = random_password.rds_password.result

  vpc_security_group_ids = [module.rds_security_group.security_group_id]

  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  backup_retention_period = var.environment == "production" ? 7 : 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = var.environment == "production"

  performance_insights_enabled = var.enable_monitoring
  monitoring_interval         = var.enable_monitoring ? 60 : 0

  tags = merge(local.common_tags, {
    Type = "Database"
  })
}

resource "random_password" "rds_password" {
  length  = 16
  special = true
}

# Store RDS password in AWS Systems Manager Parameter Store
resource "aws_ssm_parameter" "rds_password" {
  name        = "/${local.name_prefix}/rds/password"
  description = "RDS password for ${local.name_prefix} database"
  type        = "SecureString"
  value       = random_password.rds_password.result

  tags = local.common_tags
}
```

---

## 🚀 **Exercise 6.2: Custom Module Integration (15 minutes)**

### Step 1: Add Custom EC2 Module Integration
Continue with **main.tf**:

```hcl
# Custom EC2 instances with advanced configuration
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.environment == "production" ? "t3.medium" : "t3.micro"

  vpc_security_group_ids = [module.web_security_group.security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_host     = module.rds.db_instance_endpoint
    bucket_name = module.s3_app_data.s3_bucket_id
    environment = var.environment
    username    = var.username
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

# Auto Scaling Group using community module
module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.0"

  name = "${local.name_prefix}-asg"

  min_size         = 1
  max_size         = var.environment == "production" ? 6 : 2
  desired_capacity = var.environment == "production" ? 2 : 1

  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = module.alb.target_group_arns
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template = {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Auto Scaling policies
  scaling_policies = {
    cpu-high = {
      policy_type        = "TargetTrackingScaling"
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 70.0
      }
    }
    
    alb-requests = {
      policy_type        = "TargetTrackingScaling"
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ALBRequestCountPerTarget"
          resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
        }
        target_value = 1000.0
      }
    }
  }

  tags = local.common_tags
}

# S3 bucket for application data using community module
module "s3_app_data" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name_prefix}-app-data-${random_string.bucket_suffix.result}"

  # Bucket configuration
  force_destroy = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.s3_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  cors_rule = [
    {
      allowed_methods = ["GET", "POST", "PUT"]
      allowed_origins = ["*"]
      allowed_headers = ["*"]
      max_age_seconds = 3000
    }
  ]

  tags = merge(local.common_tags, {
    Type = "ApplicationData"
  })
}

# KMS key for S3 encryption
resource "aws_kms_key" "s3_key" {
  description = "KMS key for S3 encryption in ${local.name_prefix}"

  tags = local.common_tags
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${local.name_prefix}-s3-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

# IAM role for EC2 instances
resource "aws_iam_role" "web" {
  name = "${local.name_prefix}-web-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.web.name
}

resource "aws_iam_role_policy" "web_app" {
  name = "${local.name_prefix}-web-policy"
  role = aws_iam_role.web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${module.s3_app_data.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.s3_app_data.s3_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = aws_ssm_parameter.rds_password.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "${local.name_prefix}-web-profile"
  role = aws_iam_role.web.name

  tags = local.common_tags
}

# Bastion host for secure access
resource "aws_instance" "bastion" {
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t3.micro"
  subnet_id               = module.vpc.public_subnets[0]
  vpc_security_group_ids  = [module.bastion_security_group.security_group_id]
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion"
    Type = "BastionHost"
  })
}
```

### Step 2: Create User Data Script
Create **user_data.sh**:

```bash
#!/bin/bash
yum update -y
yum install -y httpd php mysql awscli amazon-cloudwatch-agent

# Start and enable services
systemctl start httpd
systemctl enable httpd

# Configure CloudWatch agent
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "AWS/EC2/Custom",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
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
            "log_group_name": "/aws/ec2/${username}-${environment}/httpd/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/aws/ec2/${username}-${environment}/httpd/error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Get database password from Parameter Store
DB_PASSWORD=$(aws ssm get-parameter --name "/${username}-${environment}/rds/password" --with-decryption --query 'Parameter.Value' --output text --region us-east-2)

# Create application
cat <<EOF > /var/www/html/index.php
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Module Infrastructure - ${environment}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); }
        .header { color: #2c3e50; text-align: center; margin-bottom: 30px; }
        .module-section { background: #f8f9fa; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #007bff; }
        .status { display: inline-block; padding: 5px 10px; border-radius: 20px; color: white; font-weight: bold; }
        .success { background: #28a745; }
        .info { background: #17a2b8; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏗️ Multi-Module Infrastructure Stack</h1>
            <h2>Environment: ${environment} | Owner: ${username}</h2>
        </div>
        
        <div class="module-section">
            <h3>📊 Infrastructure Overview</h3>
            <p><strong>Instance ID:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
            <p><strong>AZ:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone'); ?></p>
            <p><strong>Private IP:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4'); ?></p>
        </div>
        
        <div class="module-section">
            <h3>🔧 Terraform Registry Modules Used</h3>
            <ul>
                <li><strong>VPC Module:</strong> <span class="status success">✓</span> terraform-aws-modules/vpc/aws</li>
                <li><strong>Security Group Module:</strong> <span class="status success">✓</span> terraform-aws-modules/security-group/aws</li>
                <li><strong>ALB Module:</strong> <span class="status success">✓</span> terraform-aws-modules/alb/aws</li>
                <li><strong>RDS Module:</strong> <span class="status success">✓</span> terraform-aws-modules/rds/aws</li>
                <li><strong>S3 Module:</strong> <span class="status success">✓</span> terraform-aws-modules/s3-bucket/aws</li>
                <li><strong>Auto Scaling Module:</strong> <span class="status success">✓</span> terraform-aws-modules/autoscaling/aws</li>
            </ul>
        </div>
        
        <div class="module-section">
            <h3>🛡️ Security & Compliance Features</h3>
            <ul>
                <li>✅ KMS encryption for S3 data</li>
                <li>✅ Parameter Store for secrets management</li>
                <li>✅ IAM roles with least privilege</li>
                <li>✅ VPC with private subnets</li>
                <li>✅ Security groups with minimal access</li>
                <li>✅ CloudWatch monitoring and logging</li>
            </ul>
        </div>
        
        <div class="module-section">
            <h3>🔍 Database Connectivity</h3>
            <?php
            try {
                \$pdo = new PDO('mysql:host=${db_host};dbname=appdb', 'admin', '${DB_PASSWORD}');
                echo '<span class="status success">✓ Database Connected</span>';
                echo '<p>Database Host: ${db_host}</p>';
            } catch(PDOException \$e) {
                echo '<span class="status info">⚠ Database Initializing</span>';
                echo '<p>Connection will be available after RDS startup completes.</p>';
            }
            ?>
        </div>
        
        <div class="module-section">
            <h3>📁 S3 Integration Test</h3>
            <?php
            \$bucket_name = '${bucket_name}';
            echo "<p><strong>App Data Bucket:</strong> \$bucket_name</p>";
            
            // Test S3 connectivity
            \$test_file = '/tmp/connectivity-test.txt';
            file_put_contents(\$test_file, "Test from instance at " . date('Y-m-d H:i:s'));
            \$upload_result = shell_exec("aws s3 cp \$test_file s3://\$bucket_name/tests/ 2>&1");
            
            if (strpos(\$upload_result, 'upload:') !== false) {
                echo '<span class="status success">✓ S3 Upload Working</span>';
            } else {
                echo '<span class="status info">⚠ S3 Permissions Setting Up</span>';
            }
            ?>
        </div>
    </div>
</body>
</html>
EOF

# Create health check endpoint
echo "OK" > /var/www/html/health

# Set permissions
chown -R apache:apache /var/www/html
chmod -R 644 /var/www/html

# Restart services
systemctl restart httpd
```

---

## 📊 **Exercise 6.3: Monitoring and Observability (10 minutes)**

### Step 1: Add CloudWatch Resources
Continue with **main.tf**:

```hcl
# CloudWatch Log Groups for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  count = var.enable_monitoring ? 2 : 0
  
  name              = "/aws/ec2/${local.name_prefix}/httpd/${count.index == 0 ? "access" : "error"}"
  retention_in_days = var.environment == "production" ? 30 : 7

  tags = local.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "app_dashboard" {
  count = var.enable_monitoring ? 1 : 0
  
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
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.lb_arn_suffix],
            [".", "TargetResponseTime", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "ALB Metrics"
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
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds.db_instance_id],
            [".", "DatabaseConnections", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-2"
          title   = "RDS Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = local.common_tags
}
```

### Step 2: Create Comprehensive Outputs
Create **outputs.tf**:

```hcl
output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.alb.lb_dns_name}"
}

output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_cidr             = module.vpc.vpc_cidr_block
    public_subnets       = module.vpc.public_subnets
    private_subnets      = module.vpc.private_subnets
    alb_dns_name         = module.alb.lb_dns_name
    alb_zone_id          = module.alb.lb_zone_id
    database_endpoint    = module.rds.db_instance_endpoint
    bastion_public_ip    = aws_instance.bastion.public_ip
  }
}

output "module_versions" {
  description = "Versions of Terraform modules used"
  value = {
    vpc_module         = "terraform-aws-modules/vpc/aws ~> 5.0"
    security_group     = "terraform-aws-modules/security-group/aws ~> 5.0" 
    alb_module         = "terraform-aws-modules/alb/aws ~> 8.0"
    rds_module         = "terraform-aws-modules/rds/aws ~> 6.0"
    s3_module          = "terraform-aws-modules/s3-bucket/aws ~> 3.0"
    autoscaling_module = "terraform-aws-modules/autoscaling/aws ~> 6.0"
  }
}

output "security_features" {
  description = "Security features implemented"
  value = {
    kms_key_id           = aws_kms_key.s3_key.id
    parameter_store_path = aws_ssm_parameter.rds_password.name
    iam_role_arn         = aws_iam_role.web.arn
    security_groups      = {
      web_sg     = module.web_security_group.security_group_id
      alb_sg     = module.alb_security_group.security_group_id
      rds_sg     = module.rds_security_group.security_group_id
      bastion_sg = module.bastion_security_group.security_group_id
    }
  }
}

output "monitoring_resources" {
  description = "Monitoring and logging resources"
  value = var.enable_monitoring ? {
    cloudwatch_log_groups = aws_cloudwatch_log_group.app_logs[*].name
    dashboard_url         = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=${aws_cloudwatch_dashboard.app_dashboard[0].dashboard_name}"
  } : null
}

output "cost_optimization_notes" {
  description = "Cost optimization features enabled"
  value = {
    single_nat_gateway     = var.environment != "production" ? "Enabled for cost savings" : "Disabled for HA"
    db_instance_class      = var.environment == "production" ? "db.t3.medium" : "db.t3.micro"
    backup_retention_days  = var.environment == "production" ? "7 days" : "1 day"
    s3_lifecycle_enabled   = "Yes - transitions to IA after 30 days, Glacier after 90 days"
  }
}
```

### Step 3: Deploy and Test the Stack
```bash
# Initialize and deploy
terraform init
terraform apply -var="username=$TF_VAR_username" -var="enable_monitoring=true"

# Test the application
ALB_DNS=$(terraform output -raw application_url | sed 's|http://||')
echo "Application URL: http://$ALB_DNS"

# Wait for instances to be ready and test
sleep 60
curl -s "http://$ALB_DNS" | grep -o "Multi-Module Infrastructure"

# Test auto-scaling by generating load (optional)
echo "Generating test load..."
for i in {1..100}; do
  curl -s "http://$ALB_DNS" > /dev/null &
done
```

---

## 🎯 **Lab Summary**

**What You've Accomplished:**
- ✅ **Module Composition**: Combined 6+ Terraform Registry modules into a cohesive application stack
- ✅ **Production Architecture**: Built VPC, ALB, Auto Scaling, RDS, and S3 using community best practices
- ✅ **Security Integration**: Implemented KMS encryption, IAM roles, Parameter Store, and security groups
- ✅ **Monitoring Stack**: Added CloudWatch logs, metrics, and dashboard for observability
- ✅ **Cost Optimization**: Environment-specific configurations for efficient resource usage
- ✅ **Advanced Patterns**: Used conditional logic, dynamic blocks, and template files

**Key Module Integration Concepts:**
- **Registry Selection**: Choosing appropriate community modules for different use cases
- **Version Management**: Pinning module versions for production stability
- **Configuration Patterns**: Passing data between modules and custom resources
- **Security Boundaries**: Combining modules while maintaining security best practices
- **Monitoring Integration**: Adding observability to modular infrastructure

**Production-Ready Features:**
- Auto Scaling with target tracking policies
- Multi-AZ deployment for high availability
- Encrypted storage with KMS keys
- Secrets management with Parameter Store
- Comprehensive logging and monitoring
- Cost-optimized configurations per environment

**Advanced Terraform Techniques:**
- Module composition and data flow
- Conditional resource creation
- Template file usage with complex interpolation
- Resource lifecycle management
- Dynamic configuration based on environment

---

## 🧹 **Cleanup**
```bash
terraform destroy -var="username=$TF_VAR_username"
```

This lab demonstrates how to leverage the Terraform Registry ecosystem while integrating custom logic and security best practices to build enterprise-grade infrastructure that is both powerful and maintainable.