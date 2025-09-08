# Lab 2: Variables and Data Sources - Complete Solution
# terraform.tfvars - Variable values for deployment

# ===========================================
# REQUIRED: Set your username
# ===========================================
username = "user1"  # CHANGE THIS to your assigned username

# ===========================================
# ENVIRONMENT CONFIGURATION
# ===========================================
environment = "dev"
aws_region  = "us-east-2"

# ===========================================
# INSTANCE CONFIGURATION
# ===========================================
instance_count    = 2
enable_monitoring = true

# Instance types per environment
instance_types = {
  dev     = "t2.micro"
  staging = "t2.small"
  prod    = "t3.small"
}

# ===========================================
# NETWORKING CONFIGURATION
# ===========================================
create_vpc = true
vpc_cidr   = "10.0.0.0/16"

subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

availability_zones = [
  "us-east-2a",
  "us-east-2b"
]

enable_dns_hostnames = true
enable_dns_support   = true

# ===========================================
# DATABASE CONFIGURATION
# ===========================================
database_config = {
  engine            = "postgres"
  engine_version    = "13.7"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  multi_az          = false
}

# Database password (sensitive)
# In production, use environment variables or secrets management
db_password = "SuperSecurePassword123!"

# ===========================================
# PROJECT CONFIGURATION
# ===========================================
project_name = "terraform-lab2"

# Common tags for all resources
common_tags = {
  Lab         = "2"
  Course      = "Terraform"
  Topic       = "Variables and Data Sources"
  ManagedBy   = "Terraform"
  Environment = "Training"
  CostCenter  = "Education"
}