# This is a placeholder file.
# Lab 10 instructs students to create a new directory (~/environment/terraform-lab10)
# and build the full configuration from the README instructions.

output "lab_instructions" {
  description = "Lab 10 setup instructions"
  value = {
    message   = "Lab 10: Terraform Cloud Integration and Remote Execution"
    setup     = "Create ~/environment/terraform-lab10 and follow README.md"
    workspace = "Create a CLI-driven workspace in Terraform Cloud"
  }
}
