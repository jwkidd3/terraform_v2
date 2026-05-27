# terraform.tfvars
#
# `username` and `aws_region` are intentionally NOT set here. Set them as
# Terraform Variables in the Terraform Cloud workspace UI (see Exercise 12.2)
# — TFC remote runs do not inherit local TF_VAR_* env vars, and your
# assigned region may differ from other students'.

environment = "gitops"
app_version = "v1.0.0"
