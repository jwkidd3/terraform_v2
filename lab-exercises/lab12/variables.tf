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
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
}

variable "desired_instances" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}

variable "app_version" {
  description = "Application version for deployment"
  type        = string
  default     = "v1.0.0"
}