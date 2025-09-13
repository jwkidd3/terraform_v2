# locals.tf - Complex Calculations and Derived Values

locals {
  # Environment-specific configuration
  current_config = var.instance_types[var.environment]
  
  # Availability zones to use (either specified or auto-detected)
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
  
  # Common naming prefix
  name_prefix = "${var.student_name}-${var.environment}"
  
  # Enhanced tagging strategy
  common_tags = merge(var.tags, {
    Environment   = var.environment
    Student       = var.student_name
    Application   = var.application_config.name
    Version       = var.application_config.version
    ManagedBy     = "Terraform"
    CreatedDate   = timestamp()
    ProjectCode   = var.cost_allocation.project_code
    CostCenter    = var.cost_allocation.cost_center
    BillingTeam   = var.cost_allocation.billing_team
    Region        = data.aws_region.current.name
    AccountId     = data.aws_caller_identity.current.account_id
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
  
  # Database subnet group name
  db_subnet_group_name = "${local.name_prefix}-db-subnet-group"
  
  # User data script for web servers
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name    = var.application_config.name
    app_version = var.application_config.version
    app_port    = var.application_config.port
    environment = var.environment
    student     = var.student_name
  }))
  
  # Calculate costs and resource limits
  estimated_monthly_cost = {
    instances = length(local.azs) * (local.current_config.instance_type == "t3.micro" ? 8.5 : local.current_config.instance_type == "t3.small" ? 17 : 34)
    storage   = length(local.azs) * local.current_config.volume_size * 0.10
    database  = var.database_config.instance_class == "db.t3.micro" ? 15 : 30
  }
  
  # Resource naming patterns
  resource_names = {
    vpc_sg           = "${local.name_prefix}-vpc-sg"
    alb_sg           = "${local.name_prefix}-alb-sg"
    database_sg      = "${local.name_prefix}-db-sg"
    launch_template  = "${local.name_prefix}-lt"
    auto_scaling     = "${local.name_prefix}-asg"
    load_balancer    = "${local.name_prefix}-alb"
    target_group     = "${local.name_prefix}-tg"
    database         = "${replace(local.name_prefix, "-", "")}db"
  }
}