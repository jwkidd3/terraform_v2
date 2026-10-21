# Lab 12: VCS-Driven Terraform Cloud with GitHub Integration
**Duration:** 45 minutes
**Difficulty:** Intermediate
**Day:** 3
**Environment:** GitHub + Terraform Cloud + AWS

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Connect a GitHub repository to Terraform Cloud
- Trigger Terraform Cloud runs automatically from `git push` to the tracked branch
- Observe speculative plans on pull requests
- Compare CLI-driven and VCS-driven workflows

> **Note on scope:** This lab focuses on the *workflow* — Git push triggering a remote run — not on building production infrastructure. The Terraform code deploys a single EC2 instance so you can spend your time on the VCS integration, not on waiting for an ALB to provision. Lab 9 already covers a multi-tier VPC architecture.

---

## 📋 **Prerequisites**
- Completion of Labs 10–11 (TFC organization created, `terraform login` done)
- GitHub account with permission to create public repositories
- Basic familiarity with `git` (`add`, `commit`, `push`)

---

## 🛠️ **Lab Setup**

### Your Username
This lab doesn't use `TF_VAR_username` from your shell — every run executes remotely in HCP Terraform, triggered by `git push`. Instead you'll set `username` (the same value `setup.sh` saved in Lab 1) as a **workspace variable** in Exercise 12.2, Step 4. To see the value:
```bash
echo "Username: $TF_VAR_username"
```

> All resources deploy to **us-east-2**. In this lab both `username` and `aws_region` are entered as workspace variables (Exercise 12.2, Step 4).

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
3. **Public** (simplest for this lab — HCP Terraform can also connect to private repositories, but a public repo avoids any access or permission issues)
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

### Step 4: Create `terraform.tfvars` in the Repo
The lab's source `terraform.tfvars` deliberately omits `username` — you'll
provide it as a Terraform Cloud workspace variable in Exercise 12.2 (TFC
remote runs do not inherit local `TF_VAR_*` env vars).

```bash
cat > terraform.tfvars <<'EOF'
environment = "gitops"
app_version = "v1.0.0"
EOF
```

**Do not commit yet** — you'll fill in the `cloud {}` block in Exercise 12.2.

---

## ☁️ **Exercise 12.2: Create the VCS-Driven Workspace (20 minutes)**

### Step 1: Decide How HCP Terraform Connects to GitHub

HCP Terraform (formerly Terraform Cloud) needs its own connection to GitHub so it can read your repository and be notified of pushes and pull requests.

> The PAT you created in Exercise 12.1 is for command-line git operations only. HCP Terraform's VCS-driven runs use a separate connection between HCP Terraform and GitHub.

**Pick one path:**

#### Path A (recommended): HCP Terraform GitHub App
**Nothing to configure up front.** The GitHub App does **not** need an organization-level VCS provider — you don't visit **Organization Settings → Providers** at all. You authorize the app for your GitHub account, and install it on your account, while creating the workspace in Step 2. Skip ahead to Step 2.

#### Path B: GitHub OAuth App — GitHub.com (Custom)
Use this only if your instructor directs you to, or if the GitHub App option isn't available to you. This is a one-time setup per HCP Terraform organization — if you already did this for another lab, skip to Step 2.

1. TFC → **Organization Settings** → **Providers** (or **VCS Providers**) → **Add a VCS Provider** → **GitHub.com (Custom)**
2. TFC displays a **Callback URL** like `https://app.terraform.io/auth/<id>/callback` — copy it
3. In a new tab, GitHub → click your avatar → **Settings** → scroll to **Developer settings** (bottom of the left sidebar) → **OAuth Apps** → **New OAuth App**
4. Fill in:

   | Field | Value |
   |-------|-------|
   | Application name | `Terraform Cloud` |
   | Homepage URL | `https://app.terraform.io` |
   | Authorization callback URL | *paste the Callback URL from TFC* |

5. Click **Register application**
6. Copy the **Client ID** that GitHub shows
7. Click **Generate a new client secret**, copy it **immediately** (GitHub only shows it once)
8. Switch back to TFC, paste **Client ID** and **Client Secret**, then **Create VCS Provider**
9. TFC redirects you to GitHub to authorize the OAuth app → click **Authorize**
10. You're back in TFC with `GitHub.com (Custom)` listed as a connected provider

### Step 2: Create the Workspace
1. https://app.terraform.io → your organization → **New** → **Workspace** (select your project, e.g. **Default Project**, if asked, then **Create**)
2. Choose **Version control workflow** *(this is the key choice — different from Labs 10–11)*
3. On **Connect to a version control provider**:
   - **Path A:** choose **GitHub** → **GitHub.com**. The first time, a GitHub pop-up asks you to authorize the HCP Terraform app (shown on GitHub as **Terraform Cloud** / **HCP Terraform**) for your GitHub account — click **Authorize**. You only do this once per GitHub account.
   - **Path B:** choose the **GitHub.com (Custom)** provider you created in Step 1.
4. Pick your `terraform-vcs-lab12-<your-username>` repository.
   - **Path A — repository not listed?** The app isn't installed on your GitHub account yet. Open the **organization menu** above the repository list and choose **Add another organization**. In the GitHub pop-up, select your personal account and install the app for **All repositories** or **Only select repositories** (pick `terraform-vcs-lab12-<your-username>`), then click **Install**. Your repository now appears in the list.
5. Workspace name: `vcs-lab12-<your-username>` *(e.g., `vcs-lab12-user1`)*
6. Leave the **Advanced options** at their defaults — the VCS branch left blank means the repository's default branch (`main`), and **Automatic speculative plans** stays enabled (you'll use it in Exercise 12.4)
7. **Create workspace**

### Step 3: Verify the VCS Connection
- TFC workspace → **Settings** → **Version Control** — shows the connected repository and the tracked branch (default branch, `main`)
- **Path A:** GitHub → click your avatar → **Settings** → **Applications** → **Installed GitHub Apps** → **Configure** next to the HCP Terraform app — under **Repository access**, confirm the app has access to `terraform-vcs-lab12-<your-username>` (**All repositories**, or the repo is in the selected list). *(Alternatively: repo → **Settings** → **GitHub Apps**.)*
- **Path B:** GitHub repo → **Settings** → **Webhooks** — you should see an `app.terraform.io` entry with a recent successful delivery

> **If a push doesn't trigger a run later in the lab**, check these in order:
> 1. **Wrong branch** — the workspace only watches its tracked branch (`main`). Pushes to any other branch are ignored by design (see Exercise 12.4).
> 2. **Path A: the app can't see the repo** — the HCP Terraform GitHub App was installed for *selected* repositories that don't include this one. Fix it under GitHub → **Settings** → **Applications** → **Installed GitHub Apps** → **Configure**.
> 3. **Path B: no webhook / broken OAuth app** — go back to **Organization Settings → Providers** and verify GitHub.com (Custom) is listed and connected. The most common gotcha is the Callback URL not matching exactly between GitHub and TFC.
> 4. **Brand-new workspace** — a workspace with no runs ignores VCS webhooks until its first run is started manually (Step 6).

### Step 4: Add Workspace Variables
**Variables** tab:

**Environment Variables** (AWS credentials, plus `CONFIRM_DESTROY`):

| Key                     | Value                                                | Sensitive |
|-------------------------|------------------------------------------------------|-----------|
| `AWS_ACCESS_KEY_ID`     | *the access key ID provided by your instructor*      | ✅        |
| `AWS_SECRET_ACCESS_KEY` | *the secret access key provided by your instructor*  | ✅        |
| `CONFIRM_DESTROY`       | `1`                                                  |           |

> **About `CONFIRM_DESTROY`:** older Terraform Cloud documentation required this environment variable before a destroy plan could run. Current HCP Terraform instead gates destroy plans with the workspace's **Settings** → **Destruction and Deletion** → **Allow destroy plans** toggle (checked during Cleanup). Setting `CONFIRM_DESTROY=1` is harmless, so add it anyway.

**Terraform Variables**:

| Key          | Value                                   |
|--------------|-----------------------------------------|
| `username`   | *your assigned username (e.g. user1)*   |
| `aws_region` | `us-east-2`                             |

> `username` and `aws_region` live in the workspace (not in `terraform.tfvars`) because each student in the shared AWS account needs a unique username, and per-student values don't belong in the Git repository. (`aws_region` would also fall back to its `us-east-2` default; setting it keeps the workspace explicit.) `environment` and `app_version` come from the `terraform.tfvars` file you just created.

### Step 5: Fill In the `cloud {}` Block
Open `main.tf` in your repo and replace the two placeholders. Use the **exact** organization name you created in Lab 10 — including any suffix you added because the name was taken (e.g. `user1-terraform-training-jd`):

```hcl
  cloud {
    organization = "user1-terraform-training"   # your actual org name from Lab 10
    workspaces {
      name = "vcs-lab12-user1"                  # the workspace you just created
    }
  }
```

### Step 6: Commit, Push, and Start the First Run
```bash
git add .
git commit -m "Initial VCS-driven Terraform Cloud configuration"
git push origin main
```

> This first push is where git asks for credentials (cloning a public repository doesn't). For **Username**, enter your GitHub username; for **Password**, paste your **Personal Access Token** — it won't echo. `credential.helper store` saves it, so later pushes won't prompt.

HCP Terraform requires the **first** run in a new VCS-driven workspace to be started manually — a workspace with no runs ignores VCS webhooks. In the TFC workspace:
1. Click **New run** (or **Actions** → **Start new run**), choose **Plan and apply**, then **Start run**. HCP Terraform fetches the latest commit on `main` — the one you just pushed. *(If a run has already appeared on its own, use that one instead.)*
2. Open the run and watch the plan stream
3. Review the plan — one EC2 instance and its security group
4. **Confirm & Apply**

From now on, every push to `main` triggers a run automatically.

---

## 🚀 **Exercise 12.3: Trigger a Change via Git Push (10 minutes)**

This is the main payoff: a code change → Git push → automatic TFC run.

### Step 1: Bump the App Version
Edit `terraform.tfvars` in your repo and change `app_version` from `v1.0.0` to `v1.1.0`:

```hcl
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
2. The plan shows the instance being **replaced** (`-/+`) with the new `AppVersion` tag — `main.tf` sets `user_data_replace_on_change = true` on `aws_instance.demo`, so a change to the rendered `user_data` script forces a new instance (user data only runs on first boot)
3. **Confirm & Apply**

### Step 4: Verify the Change in the Browser
1. Workspace → **States** → **Latest** → **Outputs** → copy `instance_url` (the replacement instance has a new public IP)
2. Give the new instance a minute or two to boot and run `user_data`, then open the URL in your browser — the page should now read `App Version: v1.1.0`

> **What just happened:** you changed one line of HCL, pushed to GitHub, and the cloud provider rebuilt the instance — no `terraform` command from your shell. This is the foundation of GitOps.

---

## 🔄 **Exercise 12.4: Speculative Plans on a Pull Request (5 minutes)**

A VCS-driven workspace tracks **one** branch (here, `main`) and **ignores pushes to every other branch**. Instead, when you open a **pull request** that targets the tracked branch, HCP Terraform runs a **speculative plan** — a plan only, never an apply — and reports the result back on the pull request. This is the foundation for PR-based review workflows.

### Step 1: Create a Feature Branch
```bash
git checkout -b feature/add-tags
```

### Step 2: Make a Trivial Change
Edit `main.tf` and add **one new line** to the existing `common_tags` block — the `CostCenter` line. Do not retype the whole block; just insert the new entry alongside the existing tags so the block ends up like this:

```hcl
  common_tags = {
    Owner       = var.username
    Environment = var.environment
    ManagedBy   = "TerraformCloud"
    Lab         = "12"
    Workflow    = "VCS-driven"
    CostCenter  = "Training" # ← only this line is new
  }
```

### Step 3: Push the Branch
```bash
git add main.tf
git commit -m "Add CostCenter tag"
git push origin feature/add-tags
```

Check the workspace's **Runs** tab — **no new run appears**. That's expected: the push went to `feature/add-tags`, which the workspace doesn't track.

### Step 4: Open a Pull Request (required)
1. GitHub → your repository → **Pull requests** → **New pull request** (or click **Compare & pull request** on the banner GitHub shows for your recently pushed branch)
2. Base: `main` ← Compare: `feature/add-tags`
3. **Create pull request**

Opening the pull request is what triggers the speculative plan.

### Step 5: Observe the Speculative Plan
1. On the pull request page, look at the **checks** section near the bottom — an HCP Terraform / Terraform Cloud status check appears, first pending, then with a plan summary (the tag change updates the instance and security group **in place** — nothing is replaced)
2. Click **Details** next to the check to open the run in HCP Terraform
3. In the TFC workspace → **Runs** tab, the same run is listed and marked as a **speculative plan / plan only**
4. **No apply happens** — there is no **Confirm & Apply** button. That's the point of speculative plans: reviewers see exactly what a change would do *before* it is merged

> **No status check on the PR?** Confirm the PR's base branch is `main`; check that TFC workspace → **Settings** → **Version Control** → **Automatic speculative plans** is enabled; and, for Path A, that the HCP Terraform GitHub App has access to the repository (GitHub → **Settings** → **Applications** → **Installed GitHub Apps**). Pull requests opened from forks do not trigger speculative plans.

### Step 6: (Optional) Merge the Pull Request
1. On GitHub, **Merge pull request** → **Confirm merge**
2. The merge is a new commit on `main`, so TFC triggers a real plan/apply run
3. Review it and **Confirm & Apply** to roll out the `CostCenter` tag

---

## 📊 **Summary: CLI-Driven vs VCS-Driven**

| Aspect             | CLI-Driven (Labs 10–11)              | VCS-Driven (Lab 12)                   |
|--------------------|---------------------------------------|---------------------------------------|
| Trigger            | `terraform apply` from your shell    | `git push` / merge to the tracked branch |
| Source of truth    | Your local working directory         | GitHub repository                     |
| Speculative plans  | Manual (`terraform plan`)            | Automatic on pull requests to the tracked branch |
| Team collaboration | Each person runs locally             | Everyone collaborates through Git     |
| Best for           | Iterative development, experiments   | Production change management          |

---

## 🎯 **Lab Summary**

### What You Accomplished
- ✅ Created a GitHub repository and connected it to a VCS-driven TFC workspace
- ✅ Triggered an automatic plan/apply by pushing to `main`
- ✅ Triggered an update by editing a variable and pushing again
- ✅ Opened a pull request and observed its speculative plan (plan only, no apply)

### Key Concepts
- **VCS-driven workflow** — TFC pulls code from GitHub on push; you don't run `terraform` locally
- **Webhook integration** — GitHub notifies TFC of pushes and pull requests; the workspace acts only on its tracked branch
- **Speculative plans** — pull requests against the tracked branch get plan-only runs reported back on the PR for review before merge
- **GitOps** — Git is the single source of truth for infrastructure configuration

---

## 🧹 **Cleanup**

### Destroy the Infrastructure
From the TFC workspace UI:
1. Open the workspace
2. **Settings** → **Destruction and Deletion** → confirm **Allow destroy plans** is enabled → **Queue destroy plan**
3. Confirm and approve the destroy run

> **Can't queue the destroy, or it errors with a "destroy plans are disabled" message?** On the same **Settings** → **Destruction and Deletion** page, make sure the **Allow destroy plans** toggle is **enabled**, save, and queue the destroy again. (`CONFIRM_DESTROY` is not what controls this in current HCP Terraform.)

### Optional Local Cleanup
```bash
cd ~/environment
rm -rf terraform-vcs-lab12-<your-username>
```

Keep the GitHub repository for reference, or delete it from GitHub when you're finished.

---

## 🎓 **Course Conclusion**
The 12 labs covered:

- **Terraform Core** (Labs 1–5): HCL, providers, variables, dependencies, modules
- **Configuration & State** (Labs 6–9): state management, registry modules, multi-environment patterns, VPC networking
- **Terraform Cloud** (Labs 10–12): CLI-driven workspaces, tag-based multi-workspace setups, and GitOps via VCS-driven workflows
