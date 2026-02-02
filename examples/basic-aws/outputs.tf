output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.web.public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.web.id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.data.id
}
