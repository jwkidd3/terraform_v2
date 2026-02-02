# outputs.tf - Show information about our resources

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_data.id
}

output "bucket_url" {
  description = "URL of the S3 bucket"
  value       = "https://${aws_s3_bucket.app_data.id}.s3.amazonaws.com"
}

output "data_files" {
  description = "Data files created with count"
  value       = aws_s3_object.data_files[*].key
}

output "app_files" {
  description = "App files created with for_each"
  value       = { for k, v in aws_s3_object.app_files : k => v.key }
}

output "total_objects" {
  description = "Total number of objects in bucket"
  value = (
    1 +  # config file
    length(aws_s3_object.data_files) +
    length(aws_s3_object.app_files) +
    1    # important file
  )
}
