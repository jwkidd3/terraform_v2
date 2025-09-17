output "application_url" {
  description = "URL to access the deployed application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "vpc_info" {
  description = "VPC configuration details"
  value = {
    vpc_id             = aws_vpc.main.id
    vpc_cidr           = aws_vpc.main.cidr_block
    public_subnet_ids  = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id
  }
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for static assets"
  value       = aws_s3_bucket.static_assets.id
}

output "auto_scaling_group" {
  description = "Auto Scaling Group information"
  value = {
    name         = aws_autoscaling_group.web.name
    min_size     = aws_autoscaling_group.web.min_size
    max_size     = aws_autoscaling_group.web.max_size
    desired_size = aws_autoscaling_group.web.desired_capacity
  }
}

output "deployment_info" {
  description = "Deployment information for GitOps workflow"
  value = {
    environment    = var.environment
    app_version    = var.app_version
    deployed_by    = "TerraformCloud-GitHub"
    git_repo       = "terraform-lab12"
    workspace_type = "VCS-driven"
  }
}