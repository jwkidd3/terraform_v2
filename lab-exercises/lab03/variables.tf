# variables.tf - Advanced Variable Definitions

# Basic validated variables
variable "username" {
  description = "Your unique username (for shared environment)"
  type        = string
  validation {
    condition     = length(var.username) > 2 && length(var.username) <= 20
    error_message = "Username must be between 3 and 20 characters."
  }
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.username))
    error_message = "Username must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

# Complex object variable for application configuration
variable "application_config" {
  description = "Application configuration settings"
  type = object({
    name    = string
    version = string
    port    = number
    health_check = object({
      path     = string
      interval = number
      timeout  = number
    })
    scaling = object({
      min_size         = number
      max_size         = number
      desired_capacity = number
    })
  })
  validation {
    condition     = var.application_config.port >= 1024 && var.application_config.port <= 65535
    error_message = "Application port must be between 1024 and 65535."
  }
  validation {
    condition     = var.application_config.scaling.min_size <= var.application_config.scaling.desired_capacity && var.application_config.scaling.desired_capacity <= var.application_config.scaling.max_size
    error_message = "Scaling configuration: min_size <= desired_capacity <= max_size."
  }
}

# Complex map for instance configurations
variable "instance_types" {
  description = "Map of environment to instance configurations"
  type = map(object({
    instance_type = string
    volume_size   = number
    monitoring    = bool
  }))
  default = {
    dev = {
      instance_type = "t3.micro"
      volume_size   = 20
      monitoring    = false
    }
    staging = {
      instance_type = "t3.small"
      volume_size   = 30
      monitoring    = true
    }
    prod = {
      instance_type = "t3.medium"
      volume_size   = 50
      monitoring    = true
    }
  }
}

# Sensitive database configuration
variable "database_config" {
  description = "Database configuration with sensitive data"
  type = object({
    engine            = string
    engine_version    = string
    instance_class    = string
    allocated_storage = number
    username          = string
    password          = string
    backup_retention  = number
    multi_az          = bool
  })
  sensitive = true
  validation {
    condition     = length(var.database_config.password) >= 12
    error_message = "Database password must be at least 12 characters long."
  }
  validation {
    condition     = can(regex("[A-Z]", var.database_config.password)) && can(regex("[a-z]", var.database_config.password)) && can(regex("[0-9]", var.database_config.password))
    error_message = "Database password must contain uppercase, lowercase, and numeric characters."
  }
}

# List of availability zones
variable "availability_zones" {
  description = "List of availability zones to deploy into"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.availability_zones) >= 2 || length(var.availability_zones) == 0
    error_message = "Either specify at least 2 availability zones or leave empty for auto-detection."
  }
}

# Enterprise tagging configuration
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Security configuration
variable "security_config" {
  description = "Security settings for the infrastructure"
  type = object({
    enable_encryption   = bool
    enable_logging      = bool
    allowed_cidr_blocks = list(string)
    ssl_certificate_arn = string
    backup_enabled      = bool
  })
  default = {
    enable_encryption   = false
    enable_logging      = true
    allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    ssl_certificate_arn = ""
    backup_enabled      = true
  }
  validation {
    condition = alltrue([
      for cidr in var.security_config.allowed_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid CIDR notation."
  }
}

# Cost allocation settings
variable "cost_allocation" {
  description = "Cost allocation and billing configuration"
  type = object({
    project_code = string
    cost_center  = string
    billing_team = string
    budget_alert = number
  })
  validation {
    condition     = can(regex("^[A-Z]{3}-[0-9]{4}$", var.cost_allocation.project_code))
    error_message = "Project code must follow format: ABC-1234."
  }
}

# Key pair for EC2 instances
variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  default     = ""
  validation {
    condition     = var.key_pair_name == "" || length(var.key_pair_name) > 0
    error_message = "Key pair name must be empty or a valid key pair name."
  }
}