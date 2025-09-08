# Lab 2: Variables and Data Sources - Complete Solution
# variables.tf - All variable definitions

# ===========================================
# REQUIRED VARIABLES (No defaults)
# ===========================================

variable "username" {
  description = "Unique username for resource naming and isolation in shared environment"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.username))
    error_message = "Username must start with a letter, contain only lowercase letters, numbers, and hyphens, and be 1-20 characters long."
  }
}

# ===========================================
# BASIC VARIABLE TYPES
# ===========================================

# String Variable
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Number Variable
variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5
    error_message = "Instance count must be between 1 and 5."
  }
}

# Boolean Variable
variable "enable_monitoring" {
  description = "Enable detailed monitoring for EC2 instances"
  type        = bool
  default     = true
}

# ===========================================
# COMPLEX VARIABLE TYPES
# ===========================================

# List Variable
variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
  
  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone must be specified."
  }
}

# Map Variable
variable "instance_types" {
  description = "Map of instance types per environment"
  type        = map(string)
  default = {
    dev     = "t2.micro"
    staging = "t2.small"
    prod    = "t3.small"
  }
}

# Object Variable
variable "database_config" {
  description = "Database configuration object"
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    allocated_storage = number
    multi_az       = bool
  })
  default = {
    engine         = "postgres"
    engine_version = "13.7"
    instance_class = "db.t3.micro"
    allocated_storage = 20
    multi_az       = false
  }
  
  validation {
    condition     = contains(["mysql", "postgres"], var.database_config.engine)
    error_message = "Database engine must be mysql or postgres."
  }
  
  validation {
    condition     = var.database_config.allocated_storage >= 20 && var.database_config.allocated_storage <= 100
    error_message = "Allocated storage must be between 20 and 100 GB."
  }
}

# ===========================================
# INFRASTRUCTURE CONFIGURATION
# ===========================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-2)."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "subnet_cidrs" {
  description = "List of subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  
  validation {
    condition = alltrue([
      for cidr in var.subnet_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

# ===========================================
# TAGGING VARIABLES
# ===========================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Lab        = "2"
    Course     = "Terraform"
    Topic      = "Variables and Data Sources"
    ManagedBy  = "Terraform"
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-lab2"
  
  validation {
    condition     = length(var.project_name) <= 30
    error_message = "Project name must be 30 characters or less."
  }
}

# ===========================================
# OPTIONAL FEATURE FLAGS
# ===========================================

variable "create_vpc" {
  description = "Whether to create a VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

# ===========================================
# SENSITIVE VARIABLES
# ===========================================

variable "db_password" {
  description = "Password for database (marked as sensitive)"
  type        = string
  default     = "ChangeMePlease123!"
  sensitive   = true
  
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}