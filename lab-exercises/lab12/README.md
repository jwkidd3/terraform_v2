# Lab 12: VCS-Driven Terraform Cloud with GitHub Integration
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 3
**Environment:** GitHub + Terraform Cloud + AWS

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Connect a GitHub repository to Terraform Cloud
- Trigger Terraform Cloud runs automatically from `git push`
- Observe speculative plans for non-default branches
- Compare CLI-driven and VCS-driven workflows

> **Note on scope:** This lab focuses on the *workflow* — Git push triggering a remote run — not on building production infrastructure. The Terraform code deploys a single EC2 instance so you can spend your time on the VCS integration, not on waiting for an ALB to provision. Lab 9 already covers production-grade architecture.

---

## 📋 **Prerequisites**
- Completion of Labs 10–11 (TFC organization created, `terraform login` done)
- GitHub account with permission to create public repositories
- Basic familiarity with `git` (`add`, `commit`, `push`)

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
export TF_VAR_username="user1"   # Replace with your assigned username
echo "Your username: $TF_VAR_username"
```

> **Key idea:** In Labs 10–11 you ran `terraform apply` from your shell and TFC executed the run. In this lab `git push` becomes the trigger — you will never run `terraform` locally after the setup.

---

## 🔗 **Exercise 12.1: Prepare a GitHub Repository (10 minutes)**

### Step 1: Generate a GitHub Personal Access Token (PAT)
GitHub requires a PAT for HTTPS git operations.

1. Go to https://github.com/settings/tokens
2. **Generate new token** → **Generate new token (classic)**
3. Note: "Terraform Cloud Lab"
4. Expiration: 7 days
5. Scopes: check **`repo`**
6. **Generate token**, then **copy it immediately** (GitHub will not show it again)

Cache the credential:
```bash
git config --global credential.helper store
```

### Step 2: Create a Public GitHub Repository
1. https://github.com → **New repository**
2. Name: `terraform-vcs-lab12-<your-username>` *(e.g., `terraform-vcs-lab12-user1`)*
3. **Public** (required for TFC free-tier VCS integration)
4. Check **Initialize this repository with a README**
5. **Create repository**

### Step 3: Clone It and Copy the Lab Files In
```bash
cd ~/environment
git clone https://github.com/<your-github-username>/terraform-vcs-lab12-<your-username>.git
cd terraform-vcs-lab12-<your-username>

cp ~/environment/terraform_v2/lab-exercises/lab12/main.tf .
cp ~/environment/terraform_v2/lab-exercises/lab12/variables.tf .
cp ~/environment/terraform_v2/lab-exercises/lab12/outputs.tf .
cp ~/environment/terraform_v2/lab-exercises/lab12/user_data.sh .
```

> When prompted for password during `git clone`, paste your **Personal Access Token**.

### Step 4: Create `terraform.tfvars` in the Repo
```bash
cat > terraform.tfvars <<EOF
username    = "${TF_VAR_username}"
environment = "gitops"
app_version = "v1.0.0"
EOF
```

**Do not commit yet** — you'll fill in the `cloud {}` block in Exercise 12.2.

---

## ☁️ **Exercise 12.2: Create the VCS-Driven Workspace (15 minutes)**

### Step 1: Create the Workspace
1. https://app.terraform.io → your organization → **New** → **Workspace**
2. Choose **Version control workflow** *(this is the key choice — different from Labs 10–11)*
3. Connect to **GitHub** — authorize Terraform Cloud if this is your first time
4. Select your `terraform-vcs-lab12-<your-username>` repository
5. Workspace name: `vcs-lab12-<your-username>` *(e.g., `vcs-lab12-user1`)*
6. **Create workspace**

### Step 2: Verify the GitHub Webhook
TFC installed a webhook on your repo automatically:
- GitHub repo → **Settings** → **Webhooks** — you should see a `app.terraform.io` entry
- TFC workspace → **Settings** → **Version Control** — shows the connected repo

### Step 3: Add Workspace Variables
**Variables** tab:

**Environment Variables** (AWS credentials):

| Key                     | Value                        | Sensitive |
|-------------------------|------------------------------|-----------|
| `AWS_ACCESS_KEY_ID`     | *your AWS access key*        | ✅        |
| `AWS_SECRET_ACCESS_KEY` | *your AWS secret access key* | ✅        |

That's it for variables — `username`, `environment`, `app_version`, and `aws_region` all come from `terraform.tfvars` or the defaults in `variables.tf`.

### Step 4: Fill In the `cloud {}` Block
Open `main.tf` in your repo and replace the two placeholders:

```hcl
  cloud {
    organization = "user1-terraform-training"   # your org from Lab 10
    workspaces {
      name = "vcs-lab12-user1"                  # the workspace you just created
    }
  }
```

### Step 5: Commit and Push — Watch the First Run Trigger
```bash
git add .
git commit -m "Initial VCS-driven Terraform Cloud configuration"
git push origin main
```

> When prompted, use your **PAT** as the password.

In the TFC workspace:
1. A new run appears within a few seconds (source: GitHub)
2. Open the run and watch the plan stream
3. Review the plan — one EC2 instance
4. **Confirm & Apply**

---

## 🚀 **Exercise 12.3: Trigger a Change via Git Push (10 minutes)**

This is the main payoff: a code change → Git push → automatic TFC run.

### Step 1: Bump the App Version
Edit `terraform.tfvars` in your repo:

```hcl
username    = "user1"
environment = "gitops"
app_version = "v1.1.0"      # ← was v1.0.0
```

### Step 2: Commit and Push
```bash
git add terraform.tfvars
git commit -m "Bump app version to v1.1.0"
git push origin main
```

### Step 3: Watch the Auto-Triggered Run
1. Switch to the TFC UI immediately — a new run should appear within seconds
2. The plan shows the `AppVersion` tag updating *and* the instance being replaced (because `user_data` changes force replacement)
3. **Confirm & Apply**

### Step 4: Verify the Change in the Browser
1. Workspace → **States** → **Latest** → **Outputs** → copy `instance_url`
2. Open it in your browser — the page should now read `App Version: v1.1.0`

> **What just happened:** you changed one line of HCL, pushed to GitHub, and the cloud provider rebuilt the instance — no `terraform` command from your shell. This is the foundation of GitOps.

---

## 🔄 **Exercise 12.4: Speculative Plans on a Feature Branch (10 minutes)**

VCS-driven workspaces run **speculative plans** for non-default branches — plans only, no apply. This is the foundation for PR-based review workflows.

### Step 1: Create a Feature Branch
```bash
git checkout -b feature/add-tags
```

### Step 2: Make a Trivial Change
Edit `main.tf` and add one tag to the `common_tags` local:

```hcl
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    ManagedBy   = "TerraformCloud"
    Lab         = "12"
    Workflow    = "VCS-driven"
    CostCenter  = "Training"   # ← new
  }
```

### Step 3: Push the Branch
```bash
git add main.tf
git commit -m "Add CostCenter tag"
git push origin feature/add-tags
```

### Step 4: Observe the Speculative Plan in TFC
1. TFC workspace → **Runs** tab → new run with a **"Plan only (speculative)"** badge
2. Open it — the plan shows what *would* change if this branch were merged
3. **No apply happens** — that's the point of speculative plans

### Step 5: (Optional) Merge via Pull Request
1. GitHub → **Pull requests** → **New pull request**
2. Base: `main` ← Compare: `feature/add-tags`
3. Notice TFC posts the plan results to the PR (if your repo allows status checks)
4. Merge — once merged into `main`, TFC triggers a real plan/apply

---

## 📊 **Summary: CLI-Driven vs VCS-Driven**

| Aspect             | CLI-Driven (Labs 10–11)              | VCS-Driven (Lab 12)                   |
|--------------------|---------------------------------------|---------------------------------------|
| Trigger            | `terraform apply` from your shell    | `git push` to the connected branch    |
| Source of truth    | Your local working directory         | GitHub repository                     |
| Speculative plans  | Manual (`terraform plan`)            | Automatic on every branch push        |
| Team collaboration | Each person runs locally             | Everyone collaborates through Git     |
| Best for           | Iterative development, experiments   | Production change management          |

---

## 🎯 **Lab Summary**

### What You Accomplished
- ✅ Created a GitHub repository and connected it to a VCS-driven TFC workspace
- ✅ Triggered an automatic plan/apply by pushing to `main`
- ✅ Triggered an update by editing a variable and pushing again
- ✅ Observed a speculative plan on a feature branch (plan only, no apply)

### Key Concepts
- **VCS-driven workflow** — TFC pulls code from GitHub on push; you don't run `terraform` locally
- **Webhook integration** — GitHub posts to TFC's webhook URL on every push
- **Speculative plans** — non-default branches get plans only, perfect for PR review
- **GitOps** — Git is the single source of truth for infrastructure state

---

## 🧹 **Cleanup**

### Destroy the Infrastructure
From the TFC workspace UI:
1. Open the workspace
2. **Settings** → **Destruction and Deletion** → **Queue destroy plan**
3. Confirm and approve the destroy run

### Optional Local Cleanup
```bash
cd ~/environment
rm -rf terraform-vcs-lab12-<your-username>
```

Keep the GitHub repository as a portfolio artifact, or delete it from GitHub when you're finished.

---

## 🎓 **Course Conclusion**
Congratulations — you've completed all 12 labs.

- **Terraform Core** (Labs 1–5): HCL, providers, variables, dependencies, modules
- **Configuration & State** (Labs 6–9): state management, registry modules, multi-environment patterns, VPC networking
- **Terraform Cloud** (Labs 10–12): CLI-driven workspaces, tag-based multi-workspace setups, and full GitOps via VCS-driven workflows
