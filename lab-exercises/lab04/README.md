# Lab 4: Resource Dependencies and Lifecycle Management
**Duration:** 45 minutes
**Difficulty:** Introductory
**Day:** 1
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Understand how Terraform manages resource dependencies
- Use `count` to create multiple similar resources
- Use `for_each` to create resources from a map
- Apply lifecycle rules to control resource behavior

---

## 📋 **Prerequisites**
- Completion of Labs 2-3
- Understanding of variables and data sources

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# Your username was saved by setup.sh in Lab 1 — confirm it is set
echo "Username: $TF_VAR_username"
```

> If it prints nothing, run `source ~/.bashrc`. If it shows the wrong name, re-run `bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <your-username>` and then `source ~/.bashrc`. Do **not** `export` a different value — every resource name includes it.

> **Note:** `username` comes **only** from `TF_VAR_username` — do not add it to `terraform.tfvars` (a value there would override the environment variable). All resources deploy to **us-east-2**, the default of the `aws_region` variable, so there is no region to set.

### How This Lab Works
`main.tf` and `outputs.tf` are already in the lab directory, but most of their contents are **commented out**. Each exercise tells you to uncomment one block, marked like this:

```hcl
# ---- Exercise 4.2: uncomment this block ----
# resource "aws_s3_object" "data_files" {
# ...
# ---- end Exercise 4.2 ----
```

To uncomment a block, select every line **between** the two marker lines (leave the marker lines themselves commented) and press **Ctrl+/** (**Cmd+/** on Mac) in the Cloud9 editor — or delete the leading `# ` from each of those lines. Save the file before running Terraform. Uncomment only the block for the exercise you are on, so each plan shows exactly the changes that exercise describes.

---

## 🔗 **Exercise 4.1: Understanding Dependencies (15 minutes)**

### Step 1: Navigate to Lab Directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab04
```

### Step 2: Review the active part of main.tf
Open `main.tf`. Everything above the `# ---- end Exercise 4.1 ----` marker is active:

```hcl
# main.tf - Resources that depend on each other
#
# This file is built up across the lab. Exercise 4.1 deploys the active
# (uncommented) resources below. Exercises 4.2, 4.3, and 4.4 each tell you to
# uncomment one clearly marked block. Uncomment only the block for the
# exercise you are on, so each plan shows exactly the changes that exercise
# describes. (Tip: in Cloud9, select the lines and press Ctrl+/ or Cmd+/ to
# toggle comments.)

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "username" {
  description = "Your unique username"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.username))
    error_message = "Username must be 3-20 characters: lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

# ---- Exercise 4.1: active from the start ----

# Random suffix - S3 bucket names are global across ALL AWS accounts
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Step 1: Create an S3 bucket first
resource "aws_s3_bucket" "app_data" {
  bucket        = "${var.username}-app-data-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name  = "${var.username} App Data"
    Owner = var.username
  }
}

# Step 2: Create bucket versioning (depends on bucket)
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id # This reference creates the dependency

  versioning_configuration {
    status = "Disabled"
  }
}

# Step 3: Upload a file (depends on bucket and versioning)
resource "aws_s3_object" "config" {
  bucket = aws_s3_bucket.app_data.id # Depends on bucket
  key    = "config/app.json"
  content = jsonencode({
    username = var.username
    version  = "1.0"
    created  = timestamp()
  })

  # This file will only be created AFTER the bucket and versioning exist
  depends_on = [aws_s3_bucket_versioning.app_data]

  tags = {
    Owner = var.username
  }

  # timestamp() changes on every plan — without ignore_changes, every apply
  # would re-upload this file.
  lifecycle {
    ignore_changes = [content]
  }
}
```

**Key points:**
- S3 bucket names are global across **all** AWS accounts, so the bucket name ends with a `random_id` suffix. Your username keeps it readable; the suffix keeps it unique.
- `aws_s3_bucket_versioning` and `aws_s3_object.config` reference `aws_s3_bucket.app_data.id` — these references are **implicit dependencies**.
- `depends_on` adds an **explicit dependency** so the config file is uploaded only after versioning is configured.
- `timestamp()` returns a new value on every run. `ignore_changes = [content]` stops Terraform from re-uploading `config/app.json` on every later plan.

### Step 3: Review the active part of outputs.tf
```hcl
# outputs.tf - Show information about our resources
#
# bucket_name and bucket_url are active from Exercise 4.1. The remaining
# outputs reference resources that are still commented out in main.tf, so
# they stay commented until Exercise 4.5.

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_data.id
}

output "bucket_url" {
  description = "URL of the S3 bucket"
  value       = "https://${aws_s3_bucket.app_data.id}.s3.amazonaws.com"
}
```

The rest of `outputs.tf` is commented out until Exercise 4.5, because those outputs reference resources you have not uncommented yet.

### Step 4: Deploy and Observe Dependencies
```bash
terraform init
terraform plan

# You should see: Plan: 4 to add, 0 to change, 0 to destroy.
# Notice the order Terraform works out on its own:
# 1. Generate the random suffix
# 2. Create the bucket (its name needs the suffix)
# 3. Then create versioning
# 4. Finally upload the file

terraform apply
```

Type `yes` when prompted. The `bucket_name` output shows your bucket's full name — later steps read it with `terraform output -raw bucket_name`.

---

## 🔢 **Exercise 4.2: Using Count (10 minutes)**

### Step 1: Uncomment the Exercise 4.2 block in main.tf
Find the `# ---- Exercise 4.2: uncomment this block ----` marker in `main.tf` and uncomment the lines below it. The result should look like this:

```hcl
# Create multiple S3 objects using count
resource "aws_s3_object" "data_files" {
  count = 2

  bucket  = aws_s3_bucket.app_data.id
  key     = "data/file-${count.index + 1}.txt"
  content = "This is data file number ${count.index + 1} for ${var.username}"

  tags = {
    Owner      = var.username
    FileNumber = tostring(count.index + 1)
  }
}
```

### Step 2: Apply the changes
```bash
terraform plan
# You should see: Plan: 2 to add, 0 to change, 0 to destroy.
# (data_files[0] and data_files[1])

terraform apply
```

### Step 3: Check your S3 bucket
```bash
aws s3 ls s3://$(terraform output -raw bucket_name) --recursive

# You should see:
# - config/app.json
# - data/file-1.txt, file-2.txt
```

---

## 🗺️ **Exercise 4.3: Using for_each (10 minutes)**

### Step 1: Uncomment the Exercise 4.3 block in main.tf
Find the `# ---- Exercise 4.3: uncomment this block ----` marker in `main.tf` and uncomment the lines below it:

```hcl
# Create different file types using for_each
resource "aws_s3_object" "app_files" {
  for_each = {
    "readme"   = "README.md"
    "config"   = "config.ini"
    "database" = "schema.sql"
  }

  bucket  = aws_s3_bucket.app_data.id
  key     = "app/${each.value}"
  content = "This is the ${each.key} file for ${var.username}'s application"

  tags = {
    Owner    = var.username
    FileType = each.key
  }
}
```

### Step 2: Apply the changes
```bash
terraform plan
# You should see: Plan: 3 to add, 0 to change, 0 to destroy.
# (one object per map entry)

terraform apply
```

### Step 3: Check the new files
```bash
aws s3 ls s3://$(terraform output -raw bucket_name) --recursive
```

> **Key Difference:** Notice how `count` creates resources indexed by number (`data_files[0]`, `data_files[1]`) while `for_each` creates resources indexed by key (`app_files["readme"]`, `app_files["config"]`). This makes `for_each` safer for additions and removals — removing an item from the middle of a count list shifts all subsequent indices.

---

## 🔄 **Exercise 4.4: Lifecycle Rules (5 minutes)**

### Step 1: Uncomment the Exercise 4.4 block in main.tf
Find the `# ---- Exercise 4.4: uncomment this block ----` marker in `main.tf` and uncomment the lines below it:

```hcl
# A resource with lifecycle rules
resource "aws_s3_object" "important_file" {
  bucket  = aws_s3_bucket.app_data.id
  key     = "important/critical-data.txt"
  content = "This file is very important for ${var.username}!"

  tags = {
    Owner    = var.username
    Critical = "true"
  }

  # Lifecycle rules
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false # Set to true in production!

    # Ignore changes to content (won't update if content changes)
    ignore_changes = [content]

    # Note: create_before_destroy is intentionally omitted.
    # An aws_s3_object is identified by bucket+key. A replacement that reuses
    # the same key just overwrites the existing object; Terraform then destroys
    # the old resource, which deletes that same key, so the file is lost even
    # though the apply succeeds. create_before_destroy is best used on resources
    # that generate unique IDs (e.g., aws_launch_template, aws_security_group).
  }
}
```

### Step 2: Apply and test lifecycle
```bash
terraform plan
# You should see: Plan: 1 to add, 0 to change, 0 to destroy.

terraform apply

# Now try changing the content string in the important_file resource and run:
terraform plan

# Terraform will report NO changes because ignore_changes = [content]
```

---

## 📤 **Exercise 4.5: Outputs for Complex Resources**

### Step 1: Uncomment the Exercise 4.5 block in outputs.tf
All the resources these outputs reference now exist, so find the `# ---- Exercise 4.5: uncomment this block ----` marker in `outputs.tf` and uncomment the lines below it:

```hcl
output "data_files" {
  description = "Data files created with count"
  value       = aws_s3_object.data_files[*].key
}

output "app_files" {
  description = "App files created with for_each"
  value       = { for k, v in aws_s3_object.app_files : k => v.key }
}

output "total_objects" {
  description = "Total number of objects in bucket"
  value = (
    1 + # config file
    length(aws_s3_object.data_files) +
    length(aws_s3_object.app_files) +
    1 # important file
  )
}
```

### Step 2: Apply the new outputs
Terraform records output values in state during `apply`, so apply once to pick up the new outputs:

```bash
terraform apply
# The plan lists only "Changes to Outputs:" (no resource changes), then:
# Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Type `yes` when prompted.

### Step 3: View your outputs
```bash
terraform output

# See how count creates a list ["data/file-1.txt", "data/file-2.txt"]
# And for_each creates a map {readme = "app/README.md", ...}
# total_objects = 7
```

---

## 📋 **Lab Summary**

### What You Accomplished:
✅ **Learned implicit dependencies**: S3 bucket → versioning → file upload
✅ **Used explicit dependencies**: `depends_on` to force creation order
✅ **Created multiple resources with count**: 2 data files
✅ **Created resources with for_each**: 3 app files from a map
✅ **Applied lifecycle rules**: prevent_destroy, ignore_changes (and learned why `create_before_destroy` is wrong for S3 objects)

### Key Concepts:

| Concept | Purpose |
|---------|---------|
| **Implicit dependency** | Terraform detects when resources reference each other |
| **Explicit dependency** | Use `depends_on` when Terraform can't detect the dependency |
| **count** | Creates a numbered list of similar resources |
| **for_each** | Creates a keyed map of resources (safer for additions/removals) |
| **prevent_destroy** | Stops accidental deletion of critical resources |
| **ignore_changes** | Ignores specific attribute changes during apply |
| **create_before_destroy** | Creates replacement before destroying original |

### Your S3 Structure:
```
<username>-app-data-bucket-<random suffix>/
├── config/
│   └── app.json
├── data/
│   ├── file-1.txt
│   └── file-2.txt
├── app/
│   ├── README.md
│   ├── config.ini
│   └── schema.sql
└── important/
    └── critical-data.txt
```

**7 objects total — created with four different Terraform techniques (a single resource, `count`, `for_each`, and lifecycle rules).**

---

## 🧹 **Clean Up**

```bash
# Remove all resources
terraform destroy

# Type 'yes' when prompted
```

---

## ❓ **Troubleshooting**

### Problem: "Cycle in dependency graph"
**Solution**: You've created a circular dependency. Check your resource references.

### Problem: "Resource already exists" or "BucketAlreadyExists"
**Solution**: The random suffix makes bucket names unique, so this usually means `TF_VAR_username` is not set to your assigned username. Run `echo $TF_VAR_username`, re-export it if needed, and run `terraform plan` again.

### Problem: "Duplicate resource" or "Reference to undeclared resource"
**Solution**: A block was uncommented twice or not at all. Each `# ---- Exercise 4.x ----` block must appear exactly once and be uncommented only in its own exercise; outputs in the Exercise 4.5 block need the 4.2–4.4 resources uncommented first.

### Problem: `terraform output -raw bucket_name` prints "No outputs found"
**Solution**: Run the command from `~/environment/terraform_v2/lab-exercises/lab04` after `terraform apply` has completed.

### Problem: "Objects must be deleted before bucket"
**Solution**: Terraform handles this automatically due to `force_destroy = true` on the bucket.

---

## 🎯 **Next Steps**

In Lab 5, you'll learn:
- How to create reusable modules
- How to organize your code into separate files
- How to share modules between different projects
