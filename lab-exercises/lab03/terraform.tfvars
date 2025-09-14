# terraform.tfvars - Production-Ready Variable Values

# Basic configuration
username = "user1"  # Replace with your assigned username
environment  = "dev"

# Application configuration
application_config = {
  name    = "enterprise-web-app"
  version = "2.1.0"
  port    = 8080
  health_check = {
    path     = "/health"
    interval = 30
    timeout  = 5
  }
  scaling = {
    min_size         = 2
    max_size         = 10
    desired_capacity = 3
  }
}

# Database configuration (sensitive)
database_config = {
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  username          = "admin"
  password          = "SecurePassword123!"
  backup_retention  = 7
  multi_az          = false
}

# Security configuration
security_config = {
  enable_encryption    = true
  enable_logging      = true
  allowed_cidr_blocks = ["10.0.0.0/16", "172.16.0.0/12"]
  ssl_certificate_arn = ""
  backup_enabled      = true
}

# Enterprise tagging
tags = {
  Owner       = "DevOps Team"
  Project     = "Terraform Training"
  Environment = "Development"
  CostCenter  = "Engineering"
  Compliance  = "Required"
}

# Cost allocation
cost_allocation = {
  project_code = "TRF-2024"
  cost_center  = "Engineering"
  billing_team = "Platform Team"
  budget_alert = 100
}