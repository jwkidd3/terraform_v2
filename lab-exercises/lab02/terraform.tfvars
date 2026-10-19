# terraform.tfvars
#
# `username` is intentionally NOT set here (a value in this file would
# override TF_VAR_username). Your username comes from TF_VAR_username,
# which lab01/setup.sh saved to ~/.bashrc in Lab 1:
#
#     echo "$TF_VAR_username"   # confirm it is set (else: source ~/.bashrc)
#
# `aws_region` is not set either: every student deploys to us-east-2,
# which is the variable's default.

environment = "dev"
