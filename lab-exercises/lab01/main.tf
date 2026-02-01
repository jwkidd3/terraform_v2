# main.tf - Your first Infrastructure as Code!

terraform {
  required_version = ">= 1.9"
  
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Configure the Docker Provider
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Your username variable
variable "username" {
  description = "Your unique username"
  type        = string
}

# Create a simple web server using Docker
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

resource "docker_container" "web" {
  image = docker_image.nginx.image_id
  name  = "${var.username}-my-first-container"
  
  ports {
    internal = 80
    external = 8080
  }
  
  # Add a custom index page
  upload {
    content = <<-EOF
      <!DOCTYPE html>
      <html>
      <head>
          <title>My First Terraform Success!</title>
          <style>
              body { font-family: Arial; text-align: center; padding: 50px; background: #f0f8ff; }
              .container { max-width: 600px; margin: 0 auto; }
              .success { color: #28a745; font-size: 2em; margin: 20px 0; }
              .info { background: #e7f3ff; padding: 20px; border-radius: 8px; margin: 20px 0; }
              .terraform { color: #623ce4; font-weight: bold; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1 class="success">🎉 Terraform Success!</h1>
              <div class="info">
                  <h2>Hello from <span class="terraform">Terraform</span>!</h2>
                  <p><strong>Container Owner:</strong> ${var.username}</p>
                  <p><strong>Created by:</strong> Infrastructure as Code</p>
                  <p><strong>Technology:</strong> Docker + Terraform</p>
                  <p><strong>Status:</strong> Learning Terraform is awesome!</p>
              </div>
              <h3>🏗️ You just created infrastructure with code!</h3>
              <p>This web server was created entirely through Terraform configuration.</p>
              <p>No manual clicking, no GUI - just pure Infrastructure as Code!</p>
          </div>
      </body>
      </html>
    EOF
    file    = "/usr/share/nginx/html/index.html"
  }
}