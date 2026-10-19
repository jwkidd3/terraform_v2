# Lab 1: Introduction to Terraform with Docker
**Duration:** 45 minutes  
**Difficulty:** Introductory
**Day:** 1  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Set up an AWS Cloud9 development environment
- Prepare Cloud9 with a setup script (100 GB disk, Terraform, Docker)
- Create a Terraform configuration using the Docker provider
- Execute the complete Terraform workflow: init, plan, apply, destroy
- Interpret Terraform plan output and state files

---

## 📋 **Prerequisites**
- AWS Management Console access
- Assigned username (user1, user2, user3, etc.)
- Basic understanding of command line

---

## 🛠️ **Exercise 1.1: Create Your Cloud9 Environment**

### Step 1: Navigate to Cloud9

1. Sign in to the **AWS Management Console**
2. In the top navigation bar, set the region to **US East (N. Virginia) us-east-1**
3. In the search bar, type **Cloud9** and select it from the results

### Step 2: Create Environment

1. Click **Create environment**
2. Set the **Name** to your assigned username (e.g., `user1`, `user2`, `user3`)

### Step 3: Configure EC2 Instance

| Setting | Value |
|---------|-------|
| **Environment type** | New EC2 instance |
| **Instance type** | m5.large (8 GiB RAM + 2 vCPU) |
| **Platform** | Amazon Linux |
| **Timeout** | 30 minutes |
| **Connection** | **Secure Shell (SSH)** |

> **IMPORTANT:** You must select **Secure Shell (SSH)** as the connection type. Do not use AWS Systems Manager (SSM).

Leave **VPC** and **Subnet** at their default values.

### Step 4: Launch

1. Click **Create**
2. Wait for the environment to provision (this may take 1-2 minutes)
3. Once ready, click the **Open** link next to your environment name to launch the Cloud9 IDE

> **IMPORTANT:** You must click **Open** to enter the Cloud9 IDE. All remaining commands in this lab are run inside the **Cloud9 terminal** (the shell panel at the bottom of the IDE).

### Step 5: Verify Environment

Run the following commands in the **Cloud9 terminal**:

```bash
# Verify Amazon Linux
cat /etc/os-release

# Check available disk space
df -h /

# Check memory
free -h

# Verify git is installed
git --version
```

### Step 6: Clone the Course Repository

```bash
cd ~/environment
git clone https://github.com/jwkidd3/terraform_v2.git
```

This repository contains all lab exercises and reference files for the course. You will work from this directory throughout the training.

```bash
# Verify the clone
ls terraform_v2/lab-exercises/
```

---

## 🛠️ **Exercise 1.2: Run the Environment Setup Script**

A fresh Cloud9 environment has a small 10 GB disk and no Terraform. The course repository includes a setup script, `setup.sh`, that prepares everything in one step:

| Step | What `setup.sh` does |
|------|----------------------|
| 1 | Grows the Cloud9 disk (EBS root volume) to **100 GB** and extends the filesystem |
| 2 | Installs **Terraform 1.9.8** (checksum-verified), plus `unzip`, `jq`, and `git` |
| 3 | Starts **Docker** and makes sure your user can run it |
| 4 | Saves your username to `~/.bashrc` as `TF_VAR_username` |

The script is safe to re-run: steps that are already done are skipped.

### Step 1: Run the Script
Replace `user1` with **your assigned username** (lowercase letters, numbers, and hyphens only):

```bash
bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh user1
```

The disk resize takes about a minute. Each step prints a ✔ when it finishes, followed by a summary like this:

```
==> Setup complete
    Username:    user1
    Disk:        100G
    Terraform:   Terraform v1.9.8
    Docker:      25.0.x
    AWS CLI:     aws-cli/2.x.x
    Git:         2.x.x
```

> **Why a username?** Everyone in the class shares one AWS account. Terraform adds your username to every resource name (for example `user1-web-server`) so your resources never collide with a classmate's.

### Step 2: Load Your Username into This Terminal
The script saved your username to `~/.bashrc`, which only applies to **new** terminals. Load it into the current one:

```bash
source ~/.bashrc
echo "Username set to: $TF_VAR_username"
```

> **Tip:** If the script printed **"Added ec2-user to the docker group"**, close this terminal tab and open a new one (**Window → New Terminal**) before continuing.

### Step 3: Verify Your Tools
```bash
# Disk should show ~100G total
df -h /

# Terraform
terraform version

# Docker (should list no containers yet, with no permission errors)
docker ps
```

**Expected output:**
```
Terraform v1.9.8
```

---

## 🐳 **Exercise 1.3: Your First Infrastructure as Code**

The configuration files for this lab are already provided in the course repository. In this exercise you will review each one before running it.

### Step 1: Navigate to the Lab Directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab01
ls
```

You should see `main.tf`, `outputs.tf`, `terraform.tfvars`, and this `README.md`.

### Step 2: Review main.tf - Your First Infrastructure!
Open `main.tf`. This is your first Terraform file — it manages a Docker image and a container:

```bash
cat main.tf
```

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

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters: lowercase letters, numbers, and hyphens."
  }
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

**Key points:**
- The `terraform` block pins the Terraform version and the Docker provider
- The `username` variable has no default and a `validation` block — Terraform rejects anything other than 3-20 lowercase letters, numbers, and hyphens
- `docker_container.web` references `docker_image.nginx.image_id`, so Terraform knows to pull the image before creating the container

### Step 3: Review outputs.tf
Open `outputs.tf`. Outputs print useful values after every `terraform apply`:

```bash
cat outputs.tf
```

```hcl
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

output "success_message" {
  description = "Congratulations message"
  value       = "🎉 Congratulations ${var.username}! You've successfully created infrastructure with Terraform!"
}
```

### Step 4: Review terraform.tfvars
```bash
cat terraform.tfvars
```

```hcl
# terraform.tfvars
#
# `username` is intentionally NOT set here. Provide it via the
# TF_VAR_username environment variable so each student in the shared
# classroom environment gets a unique value:
#
#     export TF_VAR_username="user1"   # replace with your assigned name
```

> **Note:** `username` is supplied **only** by the `TF_VAR_username` environment variable that `setup.sh` saved in Exercise 1.2 — never put it in `terraform.tfvars`. A value in `terraform.tfvars` takes precedence over `TF_VAR_*` environment variables, so it would silently replace your assigned name. Confirm it is set:
>
> ```bash
> echo $TF_VAR_username
> ```

---

## ⚙️ **Exercise 1.4: Experience the Terraform Workflow**

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
- `Plan: 2 to add, 0 to change, 0 to destroy.` (Docker image and container)
- A `Changes to Outputs:` section listing the five outputs from `outputs.tf`

### Step 3: Apply the Configuration
```bash
# This actually creates your infrastructure
terraform apply
```

- Type `yes` when prompted
- **You should see:** "Apply complete! Resources: 2 added" followed by an `Outputs:` section

### Step 4: View Your Outputs
```bash
# Show all outputs
terraform output

# Show a single output
terraform output container_name

# -raw prints just the value (no quotes) - handy in scripts
terraform output -raw web_url
```

### Step 5: View Your Success!
```bash
# Check your container is running
docker ps

# Get the container details (name comes from the container_name output)
docker inspect $(terraform output -raw container_name)
```

### Step 6: Test Your Web Server
Since we're in Cloud9, we can't directly browse to localhost:8080, but we can test it:

```bash
# Test your web server using the web_url output
curl $(terraform output -raw web_url)

# You should see your custom HTML page!
```

### Step 7: View Terraform State
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

### Key Files:
- `main.tf` - Your infrastructure definition (this IS your documentation!)
- `outputs.tf` - Values Terraform reports back after each apply
- `terraform.tfvars` - Variable values (your `username` comes from `TF_VAR_username` instead)
- `terraform.tfstate` - Terraform's knowledge of your infrastructure (created by `apply`)
- `.terraform/` and `.terraform.lock.hcl` - Downloaded providers and their pinned versions (created by `init`)

### The Terraform Commands:
- **terraform init** - Prepare your directory, download providers
- **terraform plan** - Preview what changes will be made
- **terraform apply** - Make the changes happen
- **terraform output** - Read values exposed by `outputs.tf`
- **terraform show** - View current infrastructure state

---

## 🧪 **Exercise 1.5: Experiment and Learn (Optional)**

### Try Making Changes:
Edit `main.tf` to change the external port:
```hcl
ports {
  internal = 80
  external = 9090  # Changed from 8080
}
```

Then run:
```bash
terraform plan   # See what will change (the container is replaced)
terraform apply  # Apply the changes
terraform output web_url             # Now shows port 9090
curl $(terraform output -raw web_url)  # Test new port
```

---

## 🧹 **Exercise 1.6: Clean Up Your Infrastructure**

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

### Problem: Cloud9 IDE does not open
**Solution**: Verify you are in the **us-east-1** region. Check that pop-ups are not blocked in your browser. Try refreshing the page.

### Problem: "Unable to access your environment"
**Solution**: Wait 1-2 minutes and try again. If the issue persists, delete the environment and recreate it.

### Problem: Disk space warning, or `df -h /` doesn't show ~100G
**Solution**: Re-run the setup script; it skips anything already done:
```bash
bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh $TF_VAR_username
```
If it reports **"Could not resize the volume"**, your Cloud9 credentials can't modify EBS volumes. Ask your instructor.

### Problem: "Docker daemon not running"
**Solution**: Run `sudo service docker start`

### Problem: "Port already in use"
**Solution**: Change the external port in main.tf to a different number

### Problem: "terraform: command not found"
**Solution**: Re-run `setup.sh` (Exercise 1.2, Step 1), then open a new terminal tab

### Problem: "No value for required variable" or "Username must be 3-20 characters"
**Solution**: Run `echo $TF_VAR_username`. If it is empty, run `source ~/.bashrc`. If it is wrong, re-run `setup.sh` with your assigned username, then `source ~/.bashrc` (lowercase letters, numbers, and hyphens only)

### Problem: "Permission denied accessing Docker socket"
**Solution**: Open a new terminal tab (**Window → New Terminal**). If that doesn't help, re-run `setup.sh`, then open another new tab

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