# outputs.tf - Show information about our resources
#
# bucket_name and bucket_url are active from Exercise 4.1. The remaining
# outputs reference resources that are still commented out in main.tf, so
# they stay commented until Exercise 4.5.

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_data.id
}

output "bucket_url" {
  description = "URL of the S3 bucket"
  value       = "https://${aws_s3_bucket.app_data.id}.s3.amazonaws.com"
}

# ---- Exercise 4.5: uncomment this block ----
# output "data_files" {
#   description = "Data files created with count"
#   value       = aws_s3_object.data_files[*].key
# }
#
# output "app_files" {
#   description = "App files created with for_each"
#   value       = { for k, v in aws_s3_object.app_files : k => v.key }
# }
#
# output "total_objects" {
#   description = "Total number of objects in bucket"
#   value = (
#     1 + # config file
#     length(aws_s3_object.data_files) +
#     length(aws_s3_object.app_files) +
#     1 # important file
#   )
# }
# ---- end Exercise 4.5 ----
