# outputs.tf - Show important information about your infrastructure

output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.web.name
}

output "container_port" {
  description = "External port for accessing the web server"
  value       = docker_container.web.ports[0].external
}

output "container_status" {
  description = "Status of the Docker container"
  value       = docker_container.web.restart
}

output "web_url" {
  description = "URL to access your web server locally"
  value       = "http://localhost:${docker_container.web.ports[0].external}"
}

output "success_message" {
  description = "Congratulations message"
  value       = "🎉 Congratulations ${var.username}! You've successfully created infrastructure with Terraform!"
}