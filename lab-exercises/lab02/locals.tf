# locals.tf - Local value definitions

locals {
  # Common naming convention
  name_prefix = "${var.username}-${var.project_name}-${var.environment}"
  
  # Common tags for all resources
  common_tags = {
    Environment    = var.environment
    Project        = var.project_name
    Owner          = var.username
    ManagedBy      = "Terraform"
    DeploymentDate = formatdate("YYYY-MM-DD-hhmm", timestamp())
  }
  
  # Resource-specific configurations
  bucket_name = "${local.name_prefix}-storage-${random_id.bucket_suffix.hex}"
  
  # Network configuration
  selected_azs = slice(data.aws_availability_zones.available.names, 0, min(2, length(data.aws_availability_zones.available.names)))
  
  # Security group rules
  ingress_rules = {
    ssh = {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "SSH access"
    }
    http = {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    }
    https = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access"
    }
  }
}