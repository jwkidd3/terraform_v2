# outputs.tf - Show important information about your infrastructure

output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.web.name
}

output "container_port" {
  description = "External port for accessing the web server"
  value       = docker_container.web.ports[0].external
}

output "container_restart_policy" {
  description = "Restart policy of the Docker container"
  value       = docker_container.web.restart
}

output "web_url" {
  description = "URL to access your web server locally"
  value       = "http://localhost:${docker_container.web.ports[0].external}"
}

output "summary" {
  description = "One-line summary of the deployed container"
  value       = "Container ${docker_container.web.name} (owner: ${var.username}) is serving nginx on port ${docker_container.web.ports[0].external}"
}
