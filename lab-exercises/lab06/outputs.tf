# outputs.tf - State and Infrastructure Information

output "state_info" {
  description = "Information about current state management"
  value = {
    backend_type   = "local"
    state_location = "${path.cwd}/terraform.tfstate"
    workspace      = terraform.workspace
  }
}

output "infrastructure_summary" {
  description = "Summary of managed infrastructure"
  value = local.bucket_info
}

output "best_practices" {
  description = "State management reminders"
  value = {
    backup_state   = "Always backup state before major operations"
    unique_naming  = "Use username prefixes for shared environments"
    state_security = "State files may contain sensitive information"
    communication  = "Coordinate with team for shared infrastructure"
  }
}