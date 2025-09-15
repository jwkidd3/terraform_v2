output "web_server_details" {
  description = "Web server information"
  value       = module.web_servers.instance_details
}

output "web_server_ips" {
  description = "Web server public IPs"
  value       = module.web_servers.public_ips
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3_bucket.s3_bucket_id
}