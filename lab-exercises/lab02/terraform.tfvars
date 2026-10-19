# terraform.tfvars
#
# `username` is intentionally NOT set here. Provide it via the
# TF_VAR_username environment variable (a value in this file would
# override TF_VAR_username):
#
#     export TF_VAR_username="user1"   # your assigned username
#
# `aws_region` is not set either: every student deploys to us-east-2,
# which is the variable's default.

environment = "development"
