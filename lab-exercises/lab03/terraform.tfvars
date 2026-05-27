# terraform.tfvars - Variable Values
#
# Both `username` and `aws_region` are intentionally NOT set here — students
# are spread across multiple AWS regions. Provide them via environment vars:
#
#     export TF_VAR_username="user1"        # your assigned username
#     export TF_VAR_aws_region="us-east-1"  # your assigned region

# Basic configuration
environment = "dev"

# Application configuration
application_config = {
  name    = "web-app"
  version = "1.0.0"
  port    = 8080
}

# Security configuration
security_config = {
  enable_encryption   = true
  enable_logging      = true
  allowed_cidr_blocks = ["10.0.0.0/16", "172.16.0.0/12"]
  backup_enabled      = true
}

# Enterprise tagging
tags = {
  Owner       = "DevOps Team"
  Project     = "Terraform Training"
  Environment = "Development"
  CostCenter  = "Engineering"
}

# Cost allocation
cost_allocation = {
  project_code = "TRF-2024"
  cost_center  = "Engineering"
  billing_team = "Platform Team"
}
