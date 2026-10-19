# terraform.tfvars
#
# `username` and `aws_region` are intentionally NOT set here. Set them as
# Terraform Variables in the HCP Terraform workspace UI (see Exercise 12.2) —
# remote runs do not inherit local TF_VAR_* env vars, and per-student values
# do not belong in the Git repository. All labs deploy to us-east-2
# (`aws_region` defaults to "us-east-2" in variables.tf).

environment = "gitops"
app_version = "v1.0.0"
