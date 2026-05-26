# terraform.tfvars
#
# `username` is intentionally NOT set here. Provide it via the
# TF_VAR_username environment variable (each student gets a unique name):
#
#     export TF_VAR_username="user1"   # replace with your assigned name
#
# `environment` and `instance_count` are also intentionally NOT set here.
# Each Terraform Cloud workspace supplies its own values for these,
# which is the entire point of the lab (same code, different config).
#
# aws_region defaults to "us-east-1" in variables.tf — override here if needed.
