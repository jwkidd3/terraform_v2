# This is a placeholder file.
# Lab 11 instructs students to create a new directory (~/environment/terraform-lab11)
# and build the full configuration from the README instructions.

output "lab_instructions" {
  description = "Lab 11 setup instructions"
  value = {
    message   = "Lab 11: Terraform Cloud Workspaces"
    setup     = "Create ~/environment/terraform-lab11 and follow README.md"
    workspace = "Use cloud {} block with tags to manage multiple workspaces"
  }
}
