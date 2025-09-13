# main.tf - Resources that depend on each other

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

# Step 1: Create an S3 bucket first
resource "aws_s3_bucket" "app_data" {
  bucket = "${var.username}-app-data-bucket"
  
  tags = {
    Name = "${var.username} App Data"
    Owner = var.username
  }
}

# Step 2: Create bucket versioning (depends on bucket)
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id  # This creates a dependency!
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Step 3: Upload a file (depends on bucket and versioning)
resource "aws_s3_object" "config" {
  bucket = aws_s3_bucket.app_data.id         # Depends on bucket
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
}

# Create multiple S3 objects using count
resource "aws_s3_object" "data_files" {
  count = 3
  
  bucket = aws_s3_bucket.app_data.id
  key    = "data/file-${count.index + 1}.txt"
  content = "This is data file number ${count.index + 1} for ${var.username}"
  
  tags = {
    Owner = var.username
    FileNumber = count.index + 1
  }
}

# Create multiple folders using count
resource "aws_s3_object" "folders" {
  count = 2
  
  bucket = aws_s3_bucket.app_data.id
  key    = "${["logs", "backups"][count.index]}/"  # Creates logs/ and backups/ folders
  content = ""  # Empty content creates a folder
  
  tags = {
    Owner = var.username
    Type = "Folder"
  }
}

# Create different file types using for_each
resource "aws_s3_object" "app_files" {
  for_each = {
    "readme"    = "README.md"
    "config"    = "config.ini" 
    "database"  = "schema.sql"
  }
  
  bucket = aws_s3_bucket.app_data.id
  key    = "app/${each.value}"
  content = "This is the ${each.key} file for ${var.username}'s application"
  
  tags = {
    Owner = var.username
    FileType = each.key
  }
}

# Create environment-specific configurations
resource "aws_s3_object" "env_configs" {
  for_each = {
    dev     = "development.json"
    staging = "staging.json"
    prod    = "production.json"
  }
  
  bucket = aws_s3_bucket.app_data.id
  key    = "environments/${each.value}"
  content = jsonencode({
    environment = each.key
    username = var.username
    debug = each.key == "dev" ? true : false
    replicas = each.key == "prod" ? 3 : 1
  })
  
  tags = {
    Owner = var.username
    Environment = each.key
  }
}

# A resource with lifecycle rules
resource "aws_s3_object" "important_file" {
  bucket = aws_s3_bucket.app_data.id
  key    = "important/critical-data.txt"
  content = "This file is very important for ${var.username}!"
  
  tags = {
    Owner = var.username
    Critical = "true"
  }
  
  # Lifecycle rules
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false  # Set to true in production!
    
    # Ignore changes to content (won't update if content changes)
    ignore_changes = [content]
    
    # Create new one before destroying old one
    create_before_destroy = true
  }
}