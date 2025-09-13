# main.tf - Enterprise Infrastructure Configuration

# Random password for RDS (demonstration purposes)
resource "random_password" "db_password" {
  count   = var.database_config.password == "" ? 1 : 0
  length  = 16
  special = true
}

# Random suffix for S3 bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = local.resource_names.alb_sg
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = {
      http  = { port = 80, cidr = ["0.0.0.0/0"] }
      https = { port = 443, cidr = ["0.0.0.0/0"] }
    }
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr
      description = "${upper(ingress.key)} traffic"
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
    Name = local.resource_names.alb_sg
    Type = "LoadBalancer"
  })
}

# Web Server Security Group
resource "aws_security_group" "web" {
  name        = local.resource_names.vpc_sg
  description = "Security group for web servers"
  vpc_id      = data.aws_vpc.default.id

  # Dynamic ingress rules from local configuration
  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }
  
  # Allow traffic from ALB
  ingress {
    from_port       = var.application_config.port
    to_port         = var.application_config.port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.vpc_sg
    Type = "WebServer"
  })
}

# Database Security Group
resource "aws_security_group" "database" {
  name        = local.resource_names.database_sg
  description = "Security group for RDS database"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
    description     = "MySQL access from web servers"
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.database_sg
    Type = "Database"
  })
}

# Launch Template for Auto Scaling Group
resource "aws_launch_template" "web" {
  name_prefix   = "${local.resource_names.launch_template}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.current_config.instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  vpc_security_group_ids = [aws_security_group.web.id]
  
  user_data = local.user_data

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.current_config.volume_size
      volume_type           = "gp3"
      encrypted             = var.security_config.enable_encryption
      kms_key_id           = var.security_config.enable_encryption ? data.aws_kms_key.ebs.arn : null
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = local.current_config.monitoring
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-web"
      Type = "WebServer"
    })
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.launch_template
    Type = "LaunchTemplate"
  })
}

# S3 Bucket for Access Logs
resource "aws_s3_bucket" "logs" {
  bucket        = "${local.name_prefix}-access-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-access-logs"
    Type = "LogStorage"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.security_config.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = local.resource_names.load_balancer
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = merge(local.common_tags, {
    Name = local.resource_names.load_balancer
    Type = "LoadBalancer"
  })
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "web" {
  name     = local.resource_names.target_group
  port     = var.application_config.port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = var.application_config.health_check.timeout
    interval            = var.application_config.health_check.interval
    path                = var.application_config.health_check.path
    matcher             = "200"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.target_group
    Type = "TargetGroup"
  })
}

# Load Balancer Listener
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

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = local.resource_names.auto_scaling
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.application_config.scaling.min_size
  max_size         = var.application_config.scaling.max_size
  desired_capacity = var.application_config.scaling.desired_capacity

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = local.resource_names.auto_scaling
    propagate_at_launch = true
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

# Database Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = local.db_subnet_group_name
  subnet_ids = data.aws_subnets.default.ids

  tags = merge(local.common_tags, {
    Name = local.db_subnet_group_name
    Type = "DatabaseSubnetGroup"
  })
}

# RDS Database Instance
resource "aws_db_instance" "main" {
  identifier = local.resource_names.database

  engine         = var.database_config.engine
  engine_version = var.database_config.engine_version
  instance_class = var.database_config.instance_class
  
  allocated_storage     = var.database_config.allocated_storage
  max_allocated_storage = var.database_config.allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = var.security_config.enable_encryption
  kms_key_id           = var.security_config.enable_encryption ? data.aws_kms_key.ebs.arn : null

  db_name  = "appdb"
  username = var.database_config.username
  password = var.database_config.password != "" ? var.database_config.password : random_password.db_password[0].result

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = var.database_config.backup_retention
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"
  
  multi_az               = var.database_config.multi_az
  publicly_accessible    = false
  
  skip_final_snapshot = true
  deletion_protection = false

  performance_insights_enabled = local.current_config.monitoring
  monitoring_interval         = local.current_config.monitoring ? 60 : 0
  
  enabled_cloudwatch_logs_exports = var.security_config.enable_logging ? ["error", "general", "slow"] : []

  tags = merge(local.common_tags, {
    Name = local.resource_names.database
    Type = "Database"
  })
}