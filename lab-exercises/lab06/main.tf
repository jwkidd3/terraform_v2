terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

variable "username" {
  description = "Your unique username"
  type        = string
}

# S3 bucket for demonstration
resource "aws_s3_bucket" "demo" {
  bucket        = "${var.username}-state-demo-bucket"
  force_destroy = true

  tags = {
    Name        = "${var.username} State Demo"
    Owner       = var.username
    Purpose     = "StateLearning"
    Environment = "training"
  }
}

# S3 bucket versioning disabled for simplicity
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Multiple S3 objects to create more state complexity
resource "aws_s3_object" "demo_files" {
  count = 3

  bucket  = aws_s3_bucket.demo.id
  key     = "demo/file-${count.index + 1}.txt"
  content = "Demo file ${count.index + 1} for ${var.username}"

  tags = {
    Owner = var.username
    Index = count.index + 1
  }
}

# Data source to understand state dependencies
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for state inspection
locals {
  bucket_info = {
    name       = aws_s3_bucket.demo.id
    arn        = aws_s3_bucket.demo.arn
    region     = data.aws_region.current.name
    account_id = data.aws_caller_identity.current.account_id
  }
}