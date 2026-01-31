# locals.tf - Complex Calculations and Derived Values

locals {
  # Environment-specific configuration
  current_config = var.instance_types[var.environment]

  # Common naming prefix
  name_prefix = "${var.username}-${var.environment}"

  # Enhanced tagging strategy
  common_tags = merge(var.tags, {
    Environment = var.environment
    Owner       = var.username
    Application = var.application_config.name
    Version     = var.application_config.version
    ManagedBy   = "Terraform"
    ProjectCode = var.cost_allocation.project_code
    CostCenter  = var.cost_allocation.cost_center
    Region      = data.aws_region.current.name
  })

  # Security group rules configuration
  ingress_rules = {
    http = {
      port        = 80
      protocol    = "tcp"
      description = "HTTP access"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    https = {
      port        = 443
      protocol    = "tcp"
      description = "HTTPS access"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    app = {
      port        = var.application_config.port
      protocol    = "tcp"
      description = "Application port"
      cidr_blocks = var.security_config.allowed_cidr_blocks
    }
    ssh = {
      port        = 22
      protocol    = "tcp"
      description = "SSH access (restricted)"
      cidr_blocks = ["10.0.0.0/8"]
    }
  }

  # Cost estimation
  estimated_monthly_cost = {
    instance = local.current_config.instance_type == "t3.micro" ? 8.5 : local.current_config.instance_type == "t3.small" ? 17 : 34
    storage  = local.current_config.volume_size * 0.10
  }

  # Resource naming patterns
  resource_names = {
    web_sg     = "${local.name_prefix}-web-sg"
    s3_bucket  = "${local.name_prefix}-logs"
    ec2_instance = "${local.name_prefix}-web"
  }
}
