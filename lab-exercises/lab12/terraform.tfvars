# terraform.tfvars
#
# `username` is intentionally NOT set here. Set it as a Terraform Variable
# in the Terraform Cloud workspace UI (see Exercise 12.2) — TFC remote runs
# do not inherit local TF_VAR_* env vars.

environment = "gitops"
app_version = "v1.0.0"

# aws_region defaults to "us-east-1" in variables.tf — override here if needed.
