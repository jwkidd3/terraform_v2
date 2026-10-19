# Lab 11: Terraform Cloud Workspaces
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 3
**Environment:** AWS Cloud9 + Terraform Cloud

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Create multiple Terraform Cloud workspaces from a single configuration
- Use `cloud { workspaces { tags = [...] } }` to enable workspace switching
- Switch between workspaces with `terraform workspace select`
- Configure workspace-specific variables to deploy different environments from the same code
- Recognize the difference between **Terraform variables** and **environment variables** in TFC

---

## 📋 **Prerequisites**
- Completion of Lab 10 (you should already have a TFC organization and have run `terraform login`)
- Your Terraform Cloud organization name from Lab 10 (e.g., `user1-terraform-training`)

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace user1 with the username assigned by your instructor
export TF_VAR_username="user1"
echo "Username: $TF_VAR_username"
```

> All resources deploy to **us-east-2** — `aws_region` defaults to `"us-east-2"` in `variables.tf`. As in Lab 10, your username must also be entered as a workspace variable in each workspace.

### Navigate to the lab directory
```bash
cd ~/environment/terraform_v2/lab-exercises/lab11
ls
```

You should see `main.tf`, `variables.tf`, `outputs.tf`, and `terraform.tfvars`. Open `main.tf` and notice the `cloud {}` block uses **`tags`**, not **`name`**:

```hcl
  cloud {
    organization = "REPLACE_WITH_YOUR_ORG"
    workspaces {
      tags = ["lab11"]
    }
  }
```

> **Why `tags` instead of `name`?**
> - `workspaces { name = "..." }` locks the working directory to one workspace.
> - `workspaces { tags = [...] }` lets the configuration target *any* workspace in your organization with that tag. This is what enables `terraform workspace list` and `terraform workspace select` to function.

---

## ✏️ **Exercise 11.1: Point the Configuration at Your Organization (5 minutes)**

### Step 1: Edit `main.tf`
Replace the organization placeholder with your TFC organization from Lab 10:

```hcl
  cloud {
    organization = "user1-terraform-training"   # ← your org name
    workspaces {
      tags = ["lab11"]
    }
  }
```

Save the file. Do **not** add a `name = ...` here — the `tags` block selects workspaces dynamically.

---

## ☁️ **Exercise 11.2: Create the Development Workspace (10 minutes)**

### Step 1: Create the Workspace in the TFC UI
1. Open https://app.terraform.io and navigate to your organization
2. Click **New** → **Workspace**
3. Choose **CLI-driven workflow**
4. Workspace name: `lab11-development`
5. Description: "Development environment workspace"
6. Click **Create workspace**

### Step 2: Tag the Workspace `lab11`
This is the critical step that connects the workspace to your `cloud {}` block, which selects workspaces with `tags = ["lab11"]`.

1. Open the workspace's **Overview** page (the page you land on after creating it)
2. In the right sidebar, find the **Tags** area and click **Manage Tags**
3. In the **Manage workspace tags** drawer, click **+ Add tag**
4. Enter `lab11` as the tag **key** and leave the value **empty** — a key-only tag is what the list form `tags = ["lab11"]` matches
5. *(Optional, for your own organization)* add a second tag with key `environment` and value `development`
6. Click **Save**

> Without the `lab11` tag, `terraform workspace select lab11-development` will fail with "workspace not found." The tag must be exactly `lab11` (lowercase, no value).

### Step 3: Add Workspace Variables
Open the **Variables** tab and add:

**Environment Variables** (AWS credentials):

| Key                     | Value                                                | Sensitive |
|-------------------------|------------------------------------------------------|-----------|
| `AWS_ACCESS_KEY_ID`     | *the access key ID provided by your instructor*      | ✅        |
| `AWS_SECRET_ACCESS_KEY` | *the secret access key provided by your instructor*  | ✅        |

**Terraform Variables**:

| Key              | Value                                   |
|------------------|-----------------------------------------|
| `username`       | *your assigned username (e.g. user1)*   |
| `aws_region`     | `us-east-2`                             |
| `environment`    | `development`                           |
| `instance_count` | `1`                                     |

> Note: `username` MUST be set as a workspace variable — TFC remote runs do not inherit your local `TF_VAR_*` env vars. `aws_region` would fall back to its `us-east-2` default, but setting it explicitly keeps each workspace self-describing. Each workspace (development and staging) has its own variables, so set all four in both, even though `username` and `aws_region` are the same in each.

### Step 4: Set Apply Method
1. In **Settings** → **General**, find **Apply Method**
2. Set it to **Manual apply** (safer while learning)
3. Save

---

## 🚀 **Exercise 11.3: Create the Staging Workspace (10 minutes)**

Repeat the steps above for a staging environment:

### Step 1: Create the Workspace
1. **New** → **Workspace** → **CLI-driven workflow**
2. Name: `lab11-staging`
3. Description: "Staging environment workspace"
4. **Create workspace**

### Step 2: Tag It
1. Workspace **Overview** → **Tags** area in the right sidebar → **Manage Tags**
2. **+ Add tag** → key `lab11`, value left empty
3. *(Optional)* **+ Add tag** → key `environment`, value `staging`
4. **Save**

### Step 3: Add Workspace Variables
Same AWS credentials, same `username` and `aws_region` as development, but **different `environment` and `instance_count`**:

| Key              | Value                                   |
|------------------|-----------------------------------------|
| `username`       | *your assigned username (e.g. user1)*   |
| `aws_region`     | `us-east-2`                             |
| `environment`    | `staging`                               |
| `instance_count` | `2`                                     |

### Step 4: Set Apply Method
**Manual apply** again.

---

## 🔧 **Exercise 11.4: Deploy to Both Workspaces (15 minutes)**

### Step 1: Initialize
```bash
cd ~/environment/terraform_v2/lab-exercises/lab11
terraform init
```

Terraform contacts TFC, discovers both workspaces tagged `lab11`, and configures the local working directory for workspace switching.

Because **more than one** workspace matches the tag, `terraform init` prompts you to choose which one to use first — a numbered list of `lab11-development` and `lab11-staging`. Enter the number for `lab11-development`. (You'll switch between them with `terraform workspace select` below.)

> **If `init` reports no matching workspaces** (or one of them is missing from the list): re-check Step 2 of Exercises 11.2 / 11.3 — the `lab11` tag must exist on both workspaces, spelled exactly, with no value.

### Step 2: List Available Workspaces
```bash
terraform workspace list
```

You should see both `lab11-development` and `lab11-staging` listed.

### Step 3: Deploy to Development
```bash
terraform workspace select lab11-development
terraform plan
```

The plan output should show **1 EC2 instance** (because `instance_count = 1` for this workspace). Apply it:

```bash
terraform apply
```

Approve when prompted. The run executes remotely in TFC.

### Step 4: Deploy to Staging
```bash
terraform workspace select lab11-staging
terraform plan
```

The plan should show **2 EC2 instances** (different `instance_count`). Apply:

```bash
terraform apply
```

### Step 5: Compare the Two Workspaces
```bash
terraform workspace select lab11-development
terraform output

terraform workspace select lab11-staging
terraform output
```

Each workspace has its own independent state, run history, and outputs. In the TFC UI, open both workspaces side-by-side and compare:

- **Resources** count: 1 vs 2
- **Variables** tab: different `environment` and `instance_count`
- **States** tab: separate state files
- **Runs** tab: independent run histories

---

## 🎯 **Lab Summary**

### What You Accomplished
- ✅ Created two TFC workspaces (`lab11-development`, `lab11-staging`) from one configuration
- ✅ Used `workspaces { tags = ["lab11"] }` to enable CLI-side workspace switching
- ✅ Configured per-workspace variables (`environment`, `instance_count`) in the TFC UI
- ✅ Deployed two distinct environments — 1 instance in dev, 2 in staging — from identical HCL

### Key Concepts
- **Tag-based workspace selection**: `workspaces { tags = [...] }` lets one configuration manage many workspaces. `workspaces { name = "..." }` locks you to one.
- **State isolation**: each workspace has its own state file; changes in one cannot affect another.
- **Variable precedence in TFC**: workspace variables override values from auto-loaded `terraform.tfvars`. This is why we leave `environment` and `instance_count` out of `terraform.tfvars` — TFC supplies them per workspace.
- **Environment vs Terraform variables**: credentials (Environment) vs HCL `variable` blocks (Terraform). Same `Variables` tab, different runtime behavior.

---

## 🧹 **Cleanup**
Destroy resources in **both** workspaces:

```bash
terraform workspace select lab11-development
terraform destroy

terraform workspace select lab11-staging
terraform destroy
```

Approve each destroy in the TFC UI. You can keep the workspaces themselves for reference, or delete them via **Settings** → **Destruction and Deletion** → **Delete from Terraform Cloud**.

---

## 🎓 **Next Steps**
In **Lab 12** you'll switch from CLI-driven to **VCS-driven** workflow — pushing code to a GitHub repository will automatically trigger Terraform Cloud runs.
