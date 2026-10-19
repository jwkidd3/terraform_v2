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
# Your username was saved by setup.sh in Lab 1 — confirm it is set
echo "Username: $TF_VAR_username"
```

> If it prints nothing, run `source ~/.bashrc`. If it shows the wrong name, re-run `bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <your-username>` and then `source ~/.bashrc`. Do **not** `export` a different value — every resource name includes it.

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
> - `workspaces { tags = [...] }` lets the configuration target *any* workspace in your organization with that tag. This is what enables `terraform workspace list` and `terraform workspace select` to function — and `terraform workspace new` creates new workspaces that already carry the tag.

---

## ✏️ **Exercise 11.1: Point the Configuration at Your Organization (5 minutes)**

### Step 1: Edit `main.tf`
Replace the organization placeholder with the **exact** organization name you created in Lab 10 — including any suffix you added because the name was taken (e.g. `user1-terraform-training-jd`):

```hcl
  cloud {
    organization = "user1-terraform-training"   # ← your actual org name from Lab 10
    workspaces {
      tags = ["lab11"]
    }
  }
```

Save the file. Do **not** add a `name = ...` here — the `tags` block selects workspaces dynamically.

---

## ☁️ **Exercise 11.2: Create Both Workspaces from the CLI (10 minutes)**

When the `cloud {}` block uses `tags`, any workspace that **Terraform itself creates** is automatically given those tags. Creating the workspaces from the CLI guarantees the `lab11` tag is attached in exactly the form `tags = ["lab11"]` searches for — no manual tagging in the UI.

### Step 1: Initialize
```bash
cd ~/environment/terraform_v2/lab-exercises/lab11
terraform init
```

Terraform contacts HCP Terraform and finds **no** workspaces tagged `lab11` yet, so `init` stops and asks you to name one:

```
No workspaces found.

  There are no workspaces with the configured tags (lab11)
  in your HCP Terraform organization. To finish initializing, Terraform needs at
  least one workspace available.

  Terraform can create a properly tagged workspace for you now. Please enter a
  name to create a new HCP Terraform workspace.

  Enter a value:
```

Type `lab11-development` and press **Enter**. `init` finishes with *"HCP Terraform has been successfully initialized!"*

> **Prompted with a numbered list instead, or not prompted at all?** Workspaces tagged `lab11` already exist in your organization (for example, from an earlier attempt). Pick `lab11-development` if it's listed, otherwise any entry — then continue with Step 2; `workspace new` reports *"already exists"* for any workspace you already have, which is fine.

### Step 2: Create the Two Workspaces
`init` only recorded your choice locally; `terraform workspace new` creates each workspace in HCP Terraform, tagged `lab11`:

```bash
terraform workspace new lab11-development
terraform workspace new lab11-staging
```

Each command prints `Created and switched to workspace "..."!`

### Step 3: List the Workspaces
```bash
terraform workspace list
```

You should see both `lab11-development` and `lab11-staging` (the `*` marks the one currently selected). In the HCP Terraform UI, both workspaces now appear in your organization with the `lab11` tag in the **Tags** area of each workspace's **Overview** page.

> **Fallback — tagging in the UI:** if a workspace was created in the UI instead (or is missing from `terraform workspace list`), open its **Overview** page → **Tags** area in the right sidebar → **Manage Tags** → **+ Add tag** → key `lab11`, value left **empty** → **Save**, then re-run `terraform workspace list`. If it still doesn't appear, delete that workspace (**Settings** → **Destruction and Deletion**) and re-create it with `terraform workspace new` as above.

---

## 🔑 **Exercise 11.3: Configure Workspace Variables (10 minutes)**

Each workspace has its own variables. Set them in the HCP Terraform UI.

### Step 1: Development Workspace Variables
Open https://app.terraform.io → your organization → **`lab11-development`** → **Variables** tab and add:

**Environment Variables** (AWS credentials):

| Key                     | Value                                                | Sensitive |
|-------------------------|------------------------------------------------------|-----------|
| `AWS_ACCESS_KEY_ID`     | *the access key ID provided by your instructor*      | ✅        |
| `AWS_SECRET_ACCESS_KEY` | *the secret access key provided by your instructor*  | ✅        |

**Terraform Variables**:

| Key              | Value                                   |
|------------------|-----------------------------------------|
| `username`       | *your username (`echo $TF_VAR_username`)* |
| `aws_region`     | `us-east-2`                             |
| `environment`    | `development`                           |
| `instance_count` | `1`                                     |

> Note: `username` MUST be set as a workspace variable — HCP Terraform remote runs do not inherit your local `TF_VAR_*` env vars. `aws_region` would fall back to its `us-east-2` default, but setting it explicitly keeps each workspace self-describing. Each workspace (development and staging) has its own variables, so set all four in both, even though `username` and `aws_region` are the same in each.

### Step 2: Staging Workspace Variables
Open **`lab11-staging`** → **Variables**. Add the same AWS credentials and the same `username` and `aws_region`, but **different `environment` and `instance_count`**:

| Key              | Value                                   |
|------------------|-----------------------------------------|
| `username`       | *your username (`echo $TF_VAR_username`)* |
| `aws_region`     | `us-east-2`                             |
| `environment`    | `staging`                               |
| `instance_count` | `2`                                     |

### Step 3: Confirm the Apply Method
In each workspace, open **Settings** → **General** and confirm **Apply Method** is **Manual apply** (the default for new workspaces — safer while learning). Save if you changed it.

---

## 🔧 **Exercise 11.4: Deploy to Both Workspaces (15 minutes)**

### Step 1: Confirm Both Workspaces Are Visible
```bash
terraform workspace list
```

You should see both `lab11-development` and `lab11-staging` listed.

### Step 2: Deploy to Development
```bash
terraform workspace select lab11-development
terraform plan
```

The plan output should show **1 EC2 instance** (because `instance_count = 1` for this workspace). Apply it:

```bash
terraform apply
```

Approve when prompted. The run executes remotely in TFC.

### Step 3: Deploy to Staging
```bash
terraform workspace select lab11-staging
terraform plan
```

The plan should show **2 EC2 instances** (different `instance_count`). Apply:

```bash
terraform apply
```

### Step 4: Compare the Two Workspaces
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
- ✅ Created two tagged TFC workspaces (`lab11-development`, `lab11-staging`) from the CLI with `terraform workspace new`
- ✅ Used `workspaces { tags = ["lab11"] }` to enable CLI-side workspace switching
- ✅ Configured per-workspace variables (`environment`, `instance_count`) in the TFC UI
- ✅ Deployed two distinct environments — 1 instance in dev, 2 in staging — from identical HCL

### Key Concepts
- **Tag-based workspace selection**: `workspaces { tags = [...] }` lets one configuration manage many workspaces, and `terraform workspace new` creates new workspaces already carrying those tags. `workspaces { name = "..." }` locks you to one.
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

Each `terraform destroy` shows the destroy plan in your terminal and prompts in the CLI — type `yes` to approve. You can keep the workspaces themselves for reference, or delete them via **Settings** → **Destruction and Deletion** → **Delete from HCP Terraform**.

---

## 🎓 **Next Steps**
In **Lab 12** you'll switch from CLI-driven to **VCS-driven** workflow — pushing code to a GitHub repository will automatically trigger Terraform Cloud runs.
