output "bucket_name" {
  description = "Application storage bucket name"
  value       = aws_s3_bucket.app_storage.id
}

output "config_files" {
  description = "List of configuration files created"
  value       = keys(aws_s3_object.config_files)
}

output "state_info" {
  description = "Information about current state backend"
  value = {
    backend_type = "local"
    state_file   = "${path.cwd}/terraform.tfstate"
  }
}