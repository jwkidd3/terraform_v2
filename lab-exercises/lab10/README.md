# Lab 10: Terraform Cloud Integration and Remote Execution
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 3
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Create a Terraform Cloud organization and CLI-driven workspace
- Migrate a local Terraform configuration to remote execution
- Store AWS credentials securely as workspace environment variables
- Run `terraform plan` and `terraform apply` remotely from your Cloud9 environment
- Inspect runs, state versions, and outputs in the Terraform Cloud UI

---

## 📋 **Prerequisites**
- Completion of Labs 1–9
- Terraform Cloud account (free tier is sufficient): https://app.terraform.io
- Understanding of state management from Lab 6

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

### Navigate to the lab directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab10
ls
```

You should see four files: `main.tf`, `variables.tf`, `outputs.tf`, and `terraform.tfvars`.
This is the same kind of EC2 configuration you've seen before — the new piece is the `cloud {}` block in `main.tf` that connects it to Terraform Cloud.

---

## ☁️ **Exercise 10.1: Create Your Terraform Cloud Organization (10 minutes)**

### Step 1: Sign in to Terraform Cloud
1. Open https://app.terraform.io in your browser
2. Sign up or sign in
3. From the top-left menu, **Create an organization** (or **New Organization**)
4. Organization name: `<your-username>-terraform-training`
   *Example:* `user1-terraform-training`
5. Use any email address you control
6. Click **Create organization**

> **Important — write your organization name down.** You will paste it into `main.tf` in Exercise 10.2 and reuse it in Labs 11 and 12.

### Step 2: Create a CLI-Driven Workspace
1. Click **New** → **Workspace**
2. Choose **CLI-driven workflow** (not Version control, not API)
3. Workspace name: `<your-username>-terraform-cloud-lab10`
   *Example:* `user1-terraform-cloud-lab10`
4. Click **Create workspace**

### Step 3: Configure Workspace Variables
In the workspace, open the **Variables** tab and add:

**Environment Variables** (these are exposed to the runner as shell environment variables — used by the AWS provider for credentials):

| Key                     | Value                          | Sensitive |
|-------------------------|--------------------------------|-----------|
| `AWS_ACCESS_KEY_ID`     | *your AWS access key*          | ✅        |
| `AWS_SECRET_ACCESS_KEY` | *your AWS secret access key*   | ✅        |

**Terraform Variables** (these map to `variable` blocks in your HCL):

| Key         | Value                                 |
|-------------|---------------------------------------|
| `username`  | *your assigned username (e.g. user1)* |

> **Important — `TF_VAR_*` is local-only:**
> The `TF_VAR_username` environment variable you exported in Cloud9 does NOT propagate to TFC's remote runners. You must set `username` here as a Terraform workspace variable, otherwise the remote plan will fail with "No value for required variable."
>
> **Why two kinds of variables?**
> - **Environment Variables** behave like `export FOO=bar` in a shell session. AWS SDKs read `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from the environment, so that's where credentials belong.
> - **Terraform Variables** are bound to your `variable "..." {}` blocks in `main.tf` / `variables.tf`. This is where your application configuration goes.
> - `aws_region` already has a default in `variables.tf`, so you don't need to set it in the workspace.

---

## 🔧 **Exercise 10.2: Point the Configuration at Your Workspace (10 minutes)**

### Step 1: Edit `main.tf`
Open `main.tf` and find the `cloud {}` block at the top:

```hcl
  cloud {
    organization = "REPLACE_WITH_YOUR_ORG"
    workspaces {
      name = "REPLACE_WITH_WORKSPACE_NAME"
    }
  }
```

Replace both placeholders with the values from Exercise 10.1:

```hcl
  cloud {
    organization = "user1-terraform-training"          # your org name
    workspaces {
      name = "user1-terraform-cloud-lab10"             # your workspace name
    }
  }
```

Save the file.

### Step 2: Authenticate the CLI with Terraform Cloud
```bash
terraform login
```

When prompted, type `yes`. A browser tab opens — generate a token, copy it, and paste it back into the terminal. The CLI stores the token in `~/.terraform.d/credentials.tfrc.json`.

### Step 3: Initialize and Run Remotely
```bash
# Connects the working directory to your TFC workspace
terraform init

# Validate the cloud connection
terraform plan
```

The plan output streams from Terraform Cloud — notice the banner:

```
Running plan in Terraform Cloud. Output will stream here.
```

That tells you the run is happening on TFC's runners, not in your Cloud9 shell.

### Step 4: Apply Remotely
```bash
terraform apply
```

Type `yes` when prompted. Watch the apply stream the same way the plan did.

---

## 🚀 **Exercise 10.3: Explore the Run in the UI (15 minutes)**

### Step 1: Inspect the Run
1. In Terraform Cloud, open your workspace
2. Click the **Runs** tab — your apply should be at the top
3. Click into the run and review:
   - **Plan**: the resources Terraform proposed
   - **Apply**: the execution log
   - **Configuration**: confirmation that TFC received your code

### Step 2: Inspect State and Outputs
1. Click the **States** tab — TFC has stored the state file remotely with a version number
2. Click the **Outputs** tab (or the **Overview** page) — you should see `instance_id`, `instance_public_ip`, and `instance_url`
3. From the terminal, fetch them locally:
   ```bash
   terraform output
   ```

### Step 3: Hit the EC2 Instance
```bash
curl http://$(terraform output -raw instance_public_ip)
```

You should see the demo HTML page.

### Step 4: Modify the Configuration via VCS-style Workflow (Local)
1. Edit `main.tf` and change the heading in the `user_data` script (e.g., from "Terraform Cloud Demo" to "TFC Remote Execution Demo")
2. Run:
   ```bash
   terraform apply
   ```
3. Approve the apply, then re-fetch the page:
   ```bash
   curl http://$(terraform output -raw instance_public_ip)
   ```
   *(Note: the EC2 instance only runs `user_data` on first boot; the change will only affect a **replacement** instance. You can force a replacement with `terraform apply -replace=aws_instance.demo`.)*

---

## 🔍 **Exercise 10.4: Best Practices Recap (5 minutes)**

You now have working infrastructure backed by Terraform Cloud. Take note of what is different from the local-state labs:

| Concept | Local (Labs 1–9) | Terraform Cloud (Lab 10) |
|---------|------------------|--------------------------|
| State file location | `terraform.tfstate` in working dir | Encrypted in Terraform Cloud |
| Plan/apply execution | Your laptop / Cloud9 | TFC runner |
| AWS credentials | `~/.aws/credentials` or env vars | Workspace env vars (encrypted) |
| State locking | None (local) or DynamoDB | Built-in, automatic |
| Audit trail | Git history | Full run history in UI |

### Best Practices Demonstrated
- ✅ **Credential isolation**: AWS keys never leave the Terraform Cloud workspace
- ✅ **Versioned state**: every apply produces a new state version you can roll back to
- ✅ **Centralized execution**: every team member runs against the same Terraform version
- ✅ **Audit log**: every plan and apply is recorded with timestamps and user identity

---

## 🧹 **Cleanup**
Destroy the demo instance before moving on:

```bash
terraform destroy
```

Type `yes` to approve. Verify in the UI that the run shows the resource being destroyed and the state file is now empty.

> **Keep the workspace** — you'll reference your organization name in Labs 11 and 12. You only need to delete the workspace if you want to remove it from your TFC account.

---

## 🎯 **Lab Summary**

### What You Accomplished
- ✅ Created a Terraform Cloud organization and a CLI-driven workspace
- ✅ Wired a local Terraform configuration to TFC via the `cloud {}` block
- ✅ Stored AWS credentials as workspace environment variables
- ✅ Ran `terraform plan` and `terraform apply` remotely
- ✅ Inspected runs, outputs, and remote state in the UI

### Key Concepts
- **`cloud {}` block** — replaces the older `backend "remote"` configuration; binds a working directory to a Terraform Cloud workspace
- **CLI-driven workflow** — you run `terraform` commands locally, but TFC executes the run on its own runners using uploaded files
- **Environment Variables vs Terraform Variables** — credentials vs configuration; both live in the workspace's **Variables** tab
- **Remote state** — TFC stores and locks state automatically; no S3+DynamoDB plumbing needed

---

## ➡️ **Next Steps**
Continue to **Lab 11**, where you'll create **multiple workspaces** (development + staging) from the same configuration using `workspaces { tags = [...] }` and `terraform workspace select`.
