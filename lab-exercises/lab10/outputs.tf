output "application_url" {
  description = "URL to access the Terraform Cloud managed application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "infrastructure_summary" {
  description = "Summary of Terraform Cloud managed infrastructure"
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_cidr              = module.vpc.vpc_cidr_block
    public_subnets        = module.vpc.public_subnets
    private_subnets       = module.vpc.private_subnets
    alb_dns_name          = aws_lb.main.dns_name
    alb_zone_id           = aws_lb.main.zone_id
    auto_scaling_group    = aws_autoscaling_group.web.name
    s3_artifacts_bucket   = aws_s3_bucket.app_artifacts.id
    dashboard_url         = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=${aws_cloudwatch_dashboard.infrastructure.dashboard_name}"
  }
}

output "terraform_cloud_details" {
  description = "Terraform Cloud workspace and execution details"
  value = {
    execution_mode        = "remote"
    state_storage        = "terraform_cloud"
    workspace_management = "cloud_based"
    collaboration_enabled = true
    # cost_estimation not available in free tier
    policy_enforcement   = "available"
    remote_operations    = "enabled"
  }
}

output "deployment_info" {
  description = "Information about the current deployment"
  value = {
    deployed_by          = "terraform_cloud"
    environment          = var.environment
    managed_resources    = "vpc, alb, asg, security_groups, cloudwatch, s3"
    high_availability    = "multi_az"
    auto_scaling_enabled = true
    monitoring_enabled   = true
    remote_execution     = true
  }
}

output "workspace_features" {
  description = "Terraform Cloud workspace features demonstrated"
  value = {
    remote_state         = "✅ Centralized state storage"
    remote_execution     = "✅ Cloud-based plan/apply"
    variable_management  = "✅ Secure variable storage"
    workspace_isolation  = "✅ Isolated execution environment"
    run_history         = "✅ Complete audit trail"
    collaboration       = "✅ Team access and permissions"
    # cost_estimation     = "Available in paid tiers"
    policy_checks       = "✅ Governance and compliance"
  }
}