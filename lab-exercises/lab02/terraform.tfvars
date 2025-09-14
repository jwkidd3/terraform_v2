# terraform.tfvars - Variable value assignments

# Replace with your actual values
username        = "user1"
environment     = "development"
project_name    = "terraform-training"
aws_region      = "us-east-2"

# Security configuration
allowed_cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production

# Feature flags
enable_monitoring = true