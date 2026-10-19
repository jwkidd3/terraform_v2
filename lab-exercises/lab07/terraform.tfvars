# terraform.tfvars
#
# `username` is intentionally NOT set here. Values in terraform.tfvars
# override TF_VAR_* environment variables, so set it in your shell instead:
#
#     export TF_VAR_username="user1"   # your assigned username
#
# All labs deploy to us-east-2 — `aws_region` defaults to "us-east-2" in
# variables.tf, so it does not need to be set either.

environment = "development"
