# terraform.tfvars
#
# `username` is intentionally NOT set here. It comes from the
# TF_VAR_username environment variable, which setup.sh saved to
# ~/.bashrc in Exercise 1.2, so each student in the shared classroom
# environment gets a unique value:
#
#     echo "$TF_VAR_username"   # confirm it is set (else: source ~/.bashrc)
