# terraform.tfvars
#
# `username` is intentionally NOT set here. Provide it via the
# TF_VAR_username environment variable so each student in the shared
# classroom environment gets a unique value:
#
#     export TF_VAR_username="user1"   # replace with your assigned name

environment = "development"
aws_region  = "us-east-1"
