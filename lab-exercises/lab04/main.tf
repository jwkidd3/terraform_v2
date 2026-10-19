# main.tf - Resources that depend on each other
#
# This file is built up across the lab. Exercise 4.1 deploys the active
# (uncommented) resources below. Exercises 4.2, 4.3, and 4.4 each tell you to
# uncomment one clearly marked block. Uncomment only the block for the
# exercise you are on, so each plan shows exactly the changes that exercise
# describes. (Tip: in Cloud9, select the lines and press Ctrl+/ or Cmd+/ to
# toggle comments.)

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "username" {
  description = "Your unique username"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters: lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

# ---- Exercise 4.1: active from the start ----

# Random suffix - S3 bucket names are global across ALL AWS accounts
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Step 1: Create an S3 bucket first
resource "aws_s3_bucket" "app_data" {
  bucket        = "${var.username}-app-data-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name  = "${var.username} App Data"
    Owner = var.username
  }
}

# Step 2: Create bucket versioning (depends on bucket)
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id # This creates a dependency!

  versioning_configuration {
    status = "Disabled"
  }
}

# Step 3: Upload a file (depends on bucket and versioning)
resource "aws_s3_object" "config" {
  bucket = aws_s3_bucket.app_data.id # Depends on bucket
  key    = "config/app.json"
  content = jsonencode({
    username = var.username
    version  = "1.0"
    created  = timestamp()
  })

  # This file will only be created AFTER the bucket and versioning exist
  depends_on = [aws_s3_bucket_versioning.app_data]

  tags = {
    Owner = var.username
  }

  # timestamp() changes on every plan — without ignore_changes, every apply
  # would re-upload this file.
  lifecycle {
    ignore_changes = [content]
  }
}

# ---- end Exercise 4.1 ----

# ---- Exercise 4.2: uncomment this block ----
# # Create multiple S3 objects using count
# resource "aws_s3_object" "data_files" {
#   count = 2
#
#   bucket  = aws_s3_bucket.app_data.id
#   key     = "data/file-${count.index + 1}.txt"
#   content = "This is data file number ${count.index + 1} for ${var.username}"
#
#   tags = {
#     Owner      = var.username
#     FileNumber = tostring(count.index + 1)
#   }
# }
# ---- end Exercise 4.2 ----

# ---- Exercise 4.3: uncomment this block ----
# # Create different file types using for_each
# resource "aws_s3_object" "app_files" {
#   for_each = {
#     "readme"   = "README.md"
#     "config"   = "config.ini"
#     "database" = "schema.sql"
#   }
#
#   bucket  = aws_s3_bucket.app_data.id
#   key     = "app/${each.value}"
#   content = "This is the ${each.key} file for ${var.username}'s application"
#
#   tags = {
#     Owner    = var.username
#     FileType = each.key
#   }
# }
# ---- end Exercise 4.3 ----

# ---- Exercise 4.4: uncomment this block ----
# # A resource with lifecycle rules
# resource "aws_s3_object" "important_file" {
#   bucket  = aws_s3_bucket.app_data.id
#   key     = "important/critical-data.txt"
#   content = "This file is very important for ${var.username}!"
#
#   tags = {
#     Owner    = var.username
#     Critical = "true"
#   }
#
#   # Lifecycle rules
#   lifecycle {
#     # Prevent accidental deletion
#     prevent_destroy = false # Set to true in production!
#
#     # Ignore changes to content (won't update if content changes)
#     ignore_changes = [content]
#
#     # Note: create_before_destroy is intentionally omitted.
#     # An aws_s3_object is identified by bucket+key. A replacement that reuses
#     # the same key just overwrites the existing object; Terraform then destroys
#     # the old resource, which deletes that same key, so the file is lost even
#     # though the apply succeeds. create_before_destroy is best used on resources
#     # that generate unique IDs (e.g., aws_launch_template, aws_security_group).
#   }
# }
# ---- end Exercise 4.4 ----
