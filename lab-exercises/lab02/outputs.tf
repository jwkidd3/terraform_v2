# outputs.tf - Output value definitions

output "account_info" {
  description = "AWS account information"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    region     = data.aws_region.current.name
  }
}

output "s3_bucket" {
  description = "S3 bucket information"
  value = {
    name        = aws_s3_bucket.app_storage.bucket
    arn         = aws_s3_bucket.app_storage.arn
    domain_name = aws_s3_bucket.app_storage.bucket_domain_name
  }
}

output "ec2_instance" {
  description = "EC2 instance information"
  value = {
    id            = aws_instance.web_server.id
    public_ip     = aws_instance.web_server.public_ip
    instance_type = aws_instance.web_server.instance_type
  }
}

output "security_group" {
  description = "Security group information"
  value = {
    id   = aws_security_group.web_sg.id
    name = aws_security_group.web_sg.name
  }
}

output "web_application_url" {
  description = "URL to access the deployed web application"
  value       = "http://${aws_instance.web_server.public_ip}"
}
