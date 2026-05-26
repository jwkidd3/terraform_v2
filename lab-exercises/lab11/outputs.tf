output "environment" {
  description = "Environment name for this workspace"
  value       = var.environment
}

output "instance_count" {
  description = "Number of instances deployed in this workspace"
  value       = var.instance_count
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.app[*].id
}
