variable "username" {
  description = "Your unique username"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "gitops"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "app_version" {
  description = "Application version label"
  type        = string
  default     = "v1.0.0"
}
