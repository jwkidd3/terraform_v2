output "terraform_cloud_workspaces" {
  description = "Terraform Cloud workspace management information"
  value = {
    message                = "Lab 11: Terraform Cloud Workspaces - Multiple workspace configuration"
    development_workspace  = "See README.md for development workspace setup"
    staging_workspace     = "See README.md for staging workspace setup"
    workspace_variables   = "Configure environment-specific variables"
    workspace_tags        = "Organize workspaces with tags"
  }
}

output "lab_completion_status" {
  description = "Lab 11 completion checklist"
  value = {
    multiple_workspaces_created = "Create development and staging workspaces"
    environment_variables_set   = "Configure different variables per workspace"
    workspace_tags_applied     = "Apply organizational tags to workspaces"
    workspace_settings_configured = "Configure workspace-specific settings"
    cross_workspace_comparison = "Compare configurations between workspaces"
  }
}