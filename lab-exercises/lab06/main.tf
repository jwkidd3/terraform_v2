terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Starting with local backend - we'll change this
}

provider "aws" {
  region = "us-east-2"
}

variable "username" {
  description = "Your unique username"
  type        = string
}

# Create some resources to manage in state
resource "aws_s3_bucket" "app_storage" {
  bucket        = "${var.username}-app-storage-lab5"
  force_destroy = true

  tags = {
    Name        = "${var.username} Application Storage"
    Environment = "development"
    Lab         = "5"
    Owner       = var.username
  }
}


# Create multiple objects to make state more complex
resource "aws_s3_object" "config_files" {
  for_each = {
    "app.json"    = jsonencode({
      app_name = "MyApplication"
      version  = "1.0.0"
      owner    = var.username
    })
    "settings.yaml" = <<-EOT
      database:
        host: localhost
        port: 5432
        name: myapp
      cache:
        type: redis
        ttl: 3600
    EOT
    "README.txt" = "This is application configuration for ${var.username}"
  }

  bucket       = aws_s3_bucket.app_storage.id
  key          = "config/${each.key}"
  content      = each.value
  content_type = "application/octet-stream"

  tags = {
    Type  = "ConfigFile"
    Owner = var.username
  }
}