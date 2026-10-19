# terraform.tfvars - Variable Values
#
# `username` is intentionally NOT set here (a value in this file would
# override TF_VAR_username). Your username comes from TF_VAR_username,
# which lab01/setup.sh saved to ~/.bashrc in Lab 1:
#
#     echo "$TF_VAR_username"   # confirm it is set (else: source ~/.bashrc)
#
# `aws_region` is not set either: every student deploys to us-east-2,
# which is the variable's default.

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
