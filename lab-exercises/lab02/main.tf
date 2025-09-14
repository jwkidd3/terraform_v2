# main.tf - Main resource definitions

# Generate random ID for unique resource naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
  
  keepers = {
    username = var.username
    project  = var.project_name
  }
}

# S3 bucket for application storage
resource "aws_s3_bucket" "app_storage" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-storage"
    Purpose     = "Application Storage"
    Compliance  = "Development"
  })
}



resource "aws_s3_bucket_public_access_block" "app_storage_pab" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Security group for EC2 instances
resource "aws_security_group" "web_sg" {
  name        = "${local.name_prefix}-web-security-group"
  description = "Security group for web servers"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-web-sg"
    Purpose = "Web Server Security"
  })
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

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

resource "aws_iam_role_policy" "ec2_s3_access" {
  name = "${local.name_prefix}-ec2-s3-access"
  role = aws_iam_role.ec2_role.id

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
        Resource = "${aws_s3_bucket.app_storage.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.app_storage.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 instance
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_types[var.environment]
  subnet_id              = data.aws_subnet.selected[0].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  monitoring = var.enable_monitoring
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
    
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-root-volume"
    })
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    bucket_name   = aws_s3_bucket.app_storage.bucket
    username      = var.username
    environment   = var.environment
    project_name  = var.project_name
    aws_region    = data.aws_region.current.name
  }))

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-server"
    Type = "WebServer"
  })

  depends_on = [
    aws_iam_role_policy.ec2_s3_access,
    aws_s3_bucket.app_storage
  ]
}