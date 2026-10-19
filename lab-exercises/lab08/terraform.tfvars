# terraform.tfvars
#
# `username` is intentionally NOT set here. Values in terraform.tfvars
# override TF_VAR_* environment variables. Your username comes from
# TF_VAR_username, which lab01/setup.sh saved to ~/.bashrc in Lab 1:
#
#     echo "$TF_VAR_username"   # confirm it is set (else: source ~/.bashrc)
#
# All labs deploy to us-east-2 — `aws_region` defaults to "us-east-2" in
# variables.tf, so it does not need to be set either.
#
# Environment-specific settings live in environments/*.tfvars and are passed
# with -var-file (see Exercise 8.2).
