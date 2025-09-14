# variables.tf - Input variable definitions

variable "username" {
  description = "Your unique username (for shared environment)"
  type        = string

  validation {
    condition     = length(var.username) >= 3 && length(var.username) <= 20
    error_message = "Username must be between 3 and 20 characters."
  }
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-training"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_types" {
  description = "Map of instance types for different environments"
  type        = map(string)
  default = {
    development = "t3.micro"
    staging     = "t3.small"
    production  = "t3.medium"
  }
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for resources"
  type        = bool
  default     = true
}