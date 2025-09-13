# outputs.tf - Output value definitions

output "account_info" {
  description = "AWS account information"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    arn        = data.aws_caller_identity.current.arn
    user_id    = data.aws_caller_identity.current.user_id
  }
}

output "infrastructure_info" {
  description = "Infrastructure deployment information"
  value = {
    region               = data.aws_region.current.name
    availability_zones   = local.selected_azs
    vpc_id              = data.aws_vpc.default.id
    subnet_ids          = data.aws_subnets.default.ids
  }
}

output "s3_bucket" {
  description = "S3 bucket information"
  value = {
    name         = aws_s3_bucket.app_storage.bucket
    arn          = aws_s3_bucket.app_storage.arn
    domain_name  = aws_s3_bucket.app_storage.bucket_domain_name
    region       = aws_s3_bucket.app_storage.region
  }
}

output "ec2_instance" {
  description = "EC2 instance information"
  value = {
    id               = aws_instance.web_server.id
    public_ip        = aws_instance.web_server.public_ip
    private_ip       = aws_instance.web_server.private_ip
    instance_type    = aws_instance.web_server.instance_type
    availability_zone = aws_instance.web_server.availability_zone
  }
}

output "security_group" {
  description = "Security group information"
  value = {
    id          = aws_security_group.web_sg.id
    name        = aws_security_group.web_sg.name
    description = aws_security_group.web_sg.description
  }
}

output "web_application_url" {
  description = "URL to access the deployed web application"
  value       = "http://${aws_instance.web_server.public_ip}"
}

output "resource_summary" {
  description = "Summary of all created resources"
  value = {
    resources_created = 8
    estimated_monthly_cost = "$15-25 USD"
    cleanup_command = "terraform destroy"
  }
}

output "next_steps" {
  description = "What to explore next"
  value = [
    "Visit the web application URL to see your deployed infrastructure",
    "Check the S3 bucket for the deployment status file",
    "Review the security group rules and IAM policies created",
    "Explore the Terraform state file to understand resource tracking"
  ]
}