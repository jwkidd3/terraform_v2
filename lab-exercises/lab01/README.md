# Lab 1: Introduction to Terraform with Docker (BEGINNER FRIENDLY)
**Duration:** 45 minutes  
**Difficulty:** Complete Beginner  
**Day:** 1  
**Environment:** AWS Cloud9

---

## 🎯 **Simple Learning Objectives**
By the end of this lab, you will be able to:
- Install and verify Terraform locally
- Understand what Infrastructure as Code means in practice
- Create your first Terraform configuration using Docker
- Experience the complete Terraform workflow: init, plan, apply, destroy
- Understand the relationship between code and infrastructure

---

## 📋 **Prerequisites**
- AWS Cloud9 environment 
- Basic understanding of command line
- No prior Terraform or Docker experience required!

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 📝 **Exercise 1.1: Install Terraform (10 minutes)**

### Step 1: Install Terraform
```bash
# Download Terraform
wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip

# Install Terraform
sudo unzip terraform_1.9.8_linux_amd64.zip -d /usr/local/bin/
rm terraform_1.9.8_linux_amd64.zip

# Verify installation
terraform version
```

### Step 2: Install Docker (Already available in Cloud9)
```bash
# Check Docker is available
docker version

# If not available, start it
sudo service docker start

# Check Docker status
docker ps
```

---

## 🐳 **Exercise 1.2: Your First Infrastructure as Code (25 minutes)**

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab1
cd terraform-lab1
```

### Step 2: Create main.tf - Your First Infrastructure!
Create your first Terraform file that manages Docker containers:

```hcl
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
```

### Step 3: Create terraform.tfvars
```hcl
# terraform.tfvars - Your variable values

# Replace "user1" with your actual username
username = "user1"
```

---

## ⚙️ **Exercise 1.3: Experience the Terraform Workflow (10 minutes)**

### Step 1: Initialize Terraform
```bash
# This downloads the Docker provider
terraform init
```

**What you should see:**
- "Terraform has been successfully initialized!"
- Docker provider downloaded and installed

### Step 2: Create a Plan
```bash
# This shows what Terraform will create
terraform plan
```

**What you should see:**
- Plan to add 2 resources (Docker image and container)
- Detailed description of what will be created

### Step 3: Apply the Configuration
```bash
# This actually creates your infrastructure
terraform apply
```

- Type `yes` when prompted
- **You should see:** "Apply complete! Resources: 2 added"

### Step 4: View Your Success!
```bash
# Check your container is running
docker ps

# Get the container details
docker inspect ${TF_VAR_username}-my-first-container
```

### Step 5: Test Your Web Server
Since we're in Cloud9, we can't directly browse to localhost:8080, but we can test it:

```bash
# Test your web server
curl http://localhost:8080

# You should see your custom HTML page!
```

### Step 6: View Terraform State
```bash
# See what Terraform knows about your infrastructure
terraform show

# List the resources Terraform is managing
terraform state list
```

---

## 🎉 **Understanding What Just Happened**

### The Magic of Infrastructure as Code:
1. **You wrote code** (main.tf) that described your desired infrastructure
2. **Terraform planned** exactly what it would create
3. **Terraform created** real infrastructure (Docker containers) from your code
4. **Terraform tracks** the state of your infrastructure

### Key Files Created:
- `main.tf` - Your infrastructure definition (this IS your documentation!)
- `terraform.tfvars` - Your configuration values
- `terraform.tfstate` - Terraform's knowledge of your infrastructure
- `.terraform/` - Terraform's working directory

### The Terraform Commands:
- **terraform init** - Prepare your directory, download providers
- **terraform plan** - Preview what changes will be made
- **terraform apply** - Make the changes happen
- **terraform show** - View current infrastructure state

---

## 🧪 **Exercise 1.4: Experiment and Learn (Optional)**

### Try Making Changes:
Edit your `terraform.tfvars` file to change the external port:

```hcl
# Try different ports
username = "user1"  # Keep your username
# No additional variables needed - experiment in main.tf
```

Edit `main.tf` to change the external port:
```hcl
ports {
  internal = 80
  external = 9090  # Changed from 8080
}
```

Then run:
```bash
terraform plan   # See what will change
terraform apply  # Apply the changes
curl http://localhost:9090  # Test new port
```

---

## 🧹 **Exercise 1.5: Clean Up Your Infrastructure**

### Destroy Everything:
```bash
# Remove all infrastructure Terraform created
terraform destroy
```

- Type `yes` when prompted
- **You should see:** "Destroy complete! Resources: 2 destroyed"

### Verify Clean Up:
```bash
# Verify container is gone
docker ps | grep $TF_VAR_username

# Should return nothing - container was removed!
```

---

## 🎯 **Lab Summary**

### What You Accomplished:
✅ **Installed Terraform** and learned basic commands  
✅ **Created your first Infrastructure as Code** using Docker  
✅ **Experienced the complete workflow:** init → plan → apply → destroy  
✅ **Managed real infrastructure** (web server container) through code  
✅ **Understood state management** - how Terraform tracks your infrastructure  
✅ **Made infrastructure changes** by editing code  
✅ **Successfully cleaned up** all resources  

### Core Concepts Learned:
- **Infrastructure as Code**: Infrastructure defined in version-controlled files
- **Providers**: How Terraform connects to different technologies (Docker, AWS, etc.)
- **Resources**: The infrastructure components you want to create
- **Variables**: How to make configurations reusable and flexible
- **State**: How Terraform tracks what it has created
- **Workflow**: The standard process for managing infrastructure with code

---

## 🔍 **Why We Started with Docker**

### Perfect Learning Environment:
- **Fast**: Containers start in seconds, not minutes
- **Safe**: No cloud costs or complex permissions
- **Visual**: You can see your web server immediately
- **Local**: Everything runs in your Cloud9 environment
- **Familiar**: Web servers are easy to understand

### Real Infrastructure Skills:
- The **same Terraform concepts** apply to AWS, Azure, GCP
- The **same workflow** works for any infrastructure
- The **same state management** principles scale to enterprise
- The **same best practices** apply everywhere

---

## ❓ **Troubleshooting**

### Problem: "Docker daemon not running"
**Solution**: Run `sudo service docker start`

### Problem: "Port already in use"
**Solution**: Change the external port in main.tf to a different number

### Problem: "terraform: command not found"
**Solution**: Re-run the installation commands from Exercise 1.1

### Problem: "Permission denied accessing Docker socket"
**Solution**: Run `sudo usermod -a -G docker $USER` and restart Cloud9

---

## 🎯 **Next Steps**

In Lab 2, you'll learn:
- How to deploy infrastructure to AWS cloud
- Working with AWS credentials and regions
- Creating cloud resources like S3 buckets and EC2 instances
- The power of cloud-scale Infrastructure as Code

### Why This Foundation Matters:
- **Same concepts, bigger scale**: What you learned applies to entire data centers
- **Enterprise ready**: The workflow scales from containers to cloud empires
- **Career valuable**: These skills are in high demand everywhere

**Congratulations! You've taken your first step into Infrastructure as Code! 🚀**

---

## 💡 **Reflection Questions**
1. How is this different from manually creating containers with `docker run`?
2. What advantages does code-based infrastructure provide?
3. How would you share this infrastructure setup with a teammate?
4. What would happen if you ran `terraform apply` twice in a row?

**You're now ready to scale up to cloud infrastructure in Lab 2!**