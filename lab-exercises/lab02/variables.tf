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
}
