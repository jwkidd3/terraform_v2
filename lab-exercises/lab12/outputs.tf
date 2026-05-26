output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.demo.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.demo.public_ip
}

output "instance_url" {
  description = "URL of the demo web page"
  value       = "http://${aws_instance.demo.public_ip}"
}

output "app_version" {
  description = "Application version currently deployed"
  value       = var.app_version
}
