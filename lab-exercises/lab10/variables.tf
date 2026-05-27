variable "username" {
  description = "Your unique username"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "terraform-cloud"
}
