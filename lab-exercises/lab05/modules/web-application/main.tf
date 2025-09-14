# Local values for consistent resource naming
locals {
  name_prefix = "${var.username}-${var.app_name}-${var.environment}"
  
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}

# Data sources to make our module flexible
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# S3 bucket for application assets
resource "aws_s3_bucket" "app_assets" {
  bucket        = "${local.name_prefix}-assets-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-assets"
    Type = "ApplicationAssets"
  })
}

# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}



# Security group for web server
resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-web-"
  description = "Security group for ${var.app_name} web server"

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
    cidr_blocks = ["0.0.0.0/0"]
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

# IAM role for EC2 to access S3
resource "aws_iam_role" "web_server" {
  name = "${local.name_prefix}-web-server-role"

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

# IAM policy for S3 access
resource "aws_iam_role_policy" "web_server_s3" {
  name = "${local.name_prefix}-s3-access"
  role = aws_iam_role.web_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_assets.arn,
          "${aws_s3_bucket.app_assets.arn}/*"
        ]
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "web_server" {
  name = "${local.name_prefix}-web-server-profile"
  role = aws_iam_role.web_server.name

  tags = local.common_tags
}

# EC2 instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  availability_zone      = data.aws_availability_zones.available.names[0]
  iam_instance_profile   = aws_iam_instance_profile.web_server.name
  monitoring             = var.enable_monitoring

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name    = var.app_name
    environment = var.environment
    username    = var.username
    bucket_name = aws_s3_bucket.app_assets.id
  }))

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-server"
  })
}

# CloudWatch alarm for CPU utilization
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = local.common_tags
}