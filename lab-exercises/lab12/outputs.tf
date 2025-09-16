output "terraform_registry_and_modules" {
  description = "Terraform Registry and Module Sharing information"
  value = {
    message              = "Lab 12: Terraform Registry and Module Sharing - Create and use custom modules"
    registry_exploration = "Browse public Terraform Registry for modules"
    custom_module_created = "Create your own web-server module"
    module_structure     = "Understand module organization and best practices"
    module_sharing       = "Share modules through version control"
  }
}

output "lab_completion_status" {
  description = "Lab 12 completion checklist"
  value = {
    registry_browsed          = "Explore public Terraform Registry modules"
    custom_module_built       = "Create custom web-server module structure"
    module_variables_defined  = "Define module inputs and validation"
    module_outputs_created    = "Create module outputs for reusability"
    module_tested            = "Test module with different configurations"
    module_documentation     = "Document module usage and examples"
  }
}