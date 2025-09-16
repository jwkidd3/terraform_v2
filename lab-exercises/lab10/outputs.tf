output "terraform_cloud_workspace" {
  description = "Terraform Cloud workspace information"
  value = {
    message             = "Lab 10: Terraform Cloud Integration - Configuration set up for remote execution"
    workspace_name      = "See README.md for workspace setup instructions"
    remote_execution    = "enabled"
    variable_management = "configured"
    team_collaboration  = "ready"
  }
}

output "lab_completion_status" {
  description = "Lab 10 completion checklist"
  value = {
    terraform_cloud_setup     = "Complete workspace creation in Terraform Cloud UI"
    aws_credentials_configured = "Set AWS credentials as environment variables in workspace"
    remote_execution_tested   = "Run terraform plan and apply remotely"
    state_management         = "Verify state is stored in Terraform Cloud"
    workspace_features       = "Explore workspace settings and team features"
  }
}