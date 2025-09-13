# outputs.tf - Comprehensive Infrastructure Outputs

# Infrastructure Information
output "environment_info" {
  description = "Environment and deployment information"
  value = {
    student_name    = var.student_name
    environment     = var.environment
    aws_region      = data.aws_region.current.name
    aws_account_id  = data.aws_caller_identity.current.account_id
    deployment_time = timestamp()
  }
}

# Networking Information
output "networking" {
  description = "Network configuration details"
  value = {
    vpc_id             = data.aws_vpc.default.id
    vpc_cidr           = data.aws_vpc.default.cidr_block
    availability_zones = local.azs
    subnet_ids         = data.aws_subnets.default.ids
    subnet_details     = { for k, v in data.aws_subnet.default : k => {
        id                = v.id
        cidr_block       = v.cidr_block
        availability_zone = v.availability_zone
      }
    }
  }
}

# Security Group Information
output "security_groups" {
  description = "Security group details"
  value = {
    alb_sg = {
      id   = aws_security_group.alb.id
      name = aws_security_group.alb.name
    }
    web_sg = {
      id   = aws_security_group.web.id
      name = aws_security_group.web.name
    }
    db_sg = {
      id   = aws_security_group.database.id
      name = aws_security_group.database.name
    }
  }
}

# Load Balancer Information
output "load_balancer" {
  description = "Application Load Balancer details"
  value = {
    dns_name    = aws_lb.main.dns_name
    zone_id     = aws_lb.main.zone_id
    arn         = aws_lb.main.arn
    hosted_zone = aws_lb.main.canonical_hosted_zone_id
  }
}

# Auto Scaling Information
output "auto_scaling" {
  description = "Auto Scaling Group configuration"
  value = {
    name             = aws_autoscaling_group.web.name
    arn              = aws_autoscaling_group.web.arn
    min_size         = aws_autoscaling_group.web.min_size
    max_size         = aws_autoscaling_group.web.max_size
    desired_capacity = aws_autoscaling_group.web.desired_capacity
  }
}

# Database Information (sensitive)
output "database" {
  description = "RDS database configuration"
  value = {
    endpoint              = aws_db_instance.main.endpoint
    port                 = aws_db_instance.main.port
    database_name        = aws_db_instance.main.db_name
    username             = aws_db_instance.main.username
    engine               = aws_db_instance.main.engine
    engine_version       = aws_db_instance.main.engine_version
    instance_class       = aws_db_instance.main.instance_class
    allocated_storage    = aws_db_instance.main.allocated_storage
    backup_retention     = aws_db_instance.main.backup_retention_period
  }
  sensitive = true
}

# Application URLs
output "application_urls" {
  description = "URLs to access the application"
  value = {
    load_balancer_url = "http://${aws_lb.main.dns_name}"
    health_check_url  = "http://${aws_lb.main.dns_name}/health"
    application_port  = var.application_config.port
  }
}

# Resource Naming
output "resource_names" {
  description = "Generated resource names for reference"
  value = local.resource_names
}

# Cost Estimation
output "cost_estimation" {
  description = "Estimated monthly costs (USD)"
  value = {
    instances_cost = local.estimated_monthly_cost.instances
    storage_cost   = local.estimated_monthly_cost.storage
    database_cost  = local.estimated_monthly_cost.database
    total_estimate = local.estimated_monthly_cost.instances + local.estimated_monthly_cost.storage + local.estimated_monthly_cost.database
    note          = "Costs are estimates and may vary based on usage patterns"
  }
}

# Tagging Information
output "tagging_strategy" {
  description = "Applied tagging strategy"
  value = {
    common_tags    = local.common_tags
    cost_allocation = var.cost_allocation
    compliance_tags = {
      project_code = var.cost_allocation.project_code
      environment  = var.environment
      managed_by   = "Terraform"
    }
  }
}

# Variable Validation Summary
output "configuration_summary" {
  description = "Summary of applied configuration"
  value = {
    application_config = {
      name    = var.application_config.name
      version = var.application_config.version
      port    = var.application_config.port
      scaling = var.application_config.scaling
    }
    instance_config = local.current_config
    security_config = {
      encryption_enabled = var.security_config.enable_encryption
      logging_enabled    = var.security_config.enable_logging
      backup_enabled     = var.security_config.backup_enabled
    }
  }
}