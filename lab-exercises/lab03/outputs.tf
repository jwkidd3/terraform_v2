# outputs.tf - Comprehensive Infrastructure Outputs

# Infrastructure Information
output "environment_info" {
  description = "Environment and deployment information"
  value = {
    username       = var.username
    environment    = var.environment
    aws_region     = data.aws_region.current.name
    aws_account_id = data.aws_caller_identity.current.account_id
  }
}

# Networking Information
output "networking" {
  description = "Network configuration details"
  value = {
    vpc_id             = data.aws_vpc.default.id
    vpc_cidr           = data.aws_vpc.default.cidr_block
    availability_zones = data.aws_availability_zones.available.names
    subnet_ids         = data.aws_subnets.default.ids
  }
}

# Security Group Information
output "security_group" {
  description = "Security group details"
  value = {
    id   = aws_security_group.web.id
    name = aws_security_group.web.name
  }
}

# S3 Bucket Information
output "s3_bucket" {
  description = "S3 bucket details"
  value = {
    name = aws_s3_bucket.logs.bucket
    arn  = aws_s3_bucket.logs.arn
  }
}

# EC2 Instance Information
output "ec2_instance" {
  description = "EC2 instance details"
  value = {
    id            = aws_instance.web.id
    public_ip     = aws_instance.web.public_ip
    instance_type = aws_instance.web.instance_type
  }
}

# Application URL
output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_instance.web.public_ip}"
}

# Resource Naming
output "resource_names" {
  description = "Generated resource names for reference"
  value       = local.resource_names
}

# Cost Estimation
output "cost_estimation" {
  description = "Estimated monthly costs (USD)"
  value = {
    instance_cost  = local.estimated_monthly_cost.instance
    storage_cost   = local.estimated_monthly_cost.storage
    total_estimate = local.estimated_monthly_cost.instance + local.estimated_monthly_cost.storage
    note           = "Costs are estimates and may vary based on usage patterns"
  }
}

# Tagging Information
output "tagging_strategy" {
  description = "Applied tagging strategy"
  value = {
    common_tags     = local.common_tags
    cost_allocation = var.cost_allocation
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
    }
    instance_config = local.current_config
    security_config = {
      encryption_enabled = var.security_config.enable_encryption
      logging_enabled    = var.security_config.enable_logging
      backup_enabled     = var.security_config.backup_enabled
    }
  }
}
