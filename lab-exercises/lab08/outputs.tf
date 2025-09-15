output "environment_info" {
  description = "Environment configuration details"
  value = {
    name                    = var.environment
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    high_availability      = var.enable_high_availability
    monitoring_enabled     = var.enable_monitoring
    backups_enabled        = var.enable_backups
    backup_retention_days  = local.backup_retention
  }
}

output "vpc_info" {
  description = "VPC configuration"
  value = {
    vpc_id             = module.vpc.vpc_id
    private_subnets    = module.vpc.private_subnets
    public_subnets     = module.vpc.public_subnets
    using_nat_gateway  = local.use_private_subnets
  }
}

output "application_endpoint" {
  description = "Application endpoint URL"
  value = var.enable_high_availability ? "http://${aws_lb.app[0].dns_name}" : "Check EC2 instances for public IPs"
}

output "security_groups" {
  description = "Security group information"
  value = {
    app_security_group_id = aws_security_group.app.id
  }
}

output "cost_optimization" {
  description = "Cost optimization settings applied"
  value = var.cost_optimization
}