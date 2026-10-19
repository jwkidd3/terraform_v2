# Instructor Pre-Flight Checklist

Read this BEFORE class day. The course assumes one shared AWS account with N students (typically 12–27).

**Deployment topology:**
- **Cloud9 IDEs all live in `us-east-1`** — each student creates their own in Lab 1, Exercise 1.1 (m5.large, Amazon Linux 2023, **SSH** connection type, not SSM).
- **All Terraform deployments land in `us-east-2`** — every lab's `aws_region` variable defaults to `us-east-2`. Students do not need to set anything to make this work.
- Cloud9 region (us-east-1) is independent from the AWS provider region (us-east-2). Running `terraform` from us-east-1 Cloud9 against `provider "aws" { region = "us-east-2" }` deploys to us-east-2 — that's the whole design.

If you ever need to **fall back** to a different deploy region (us-east-1 itself, us-west-1, or us-west-2), all three have raised quotas already and any student can override by exporting `TF_VAR_aws_region` to that region.

---

## 🚨 AWS Service Quotas (status)

All four NA regions have quotas raised to 30 for VPC / NAT / EIP / IGW:

| Region | VPCs | NAT/AZ | EIPs | IGWs |
|--------|------|--------|------|------|
| us-east-1 | 35 | 30 | 30 | 35 |
| **us-east-2** (deploy target) | **30** | **30** | **30** | **30** |
| us-west-1 | 30 | 30 | 30 | 30 |
| us-west-2 | 30 | 30 | 30 | 30 |

Each region supports ~29 concurrent students in the VPC-heavy labs (cap minus 1 default VPC slot). **us-east-2 alone covers the full 27-student class with margin.**

### Verify quota state
```bash
for region in us-east-1 us-east-2 us-west-1 us-west-2; do
  echo "=== $region ==="
  aws service-quotas list-service-quotas --service-code vpc --region $region \
    --query 'Quotas[?contains(QuotaName, `VPCs`) || contains(QuotaName, `NAT`) || contains(QuotaName, `Internet`)].{Name:QuotaName,Value:Value}' --output table
  aws service-quotas list-service-quotas --service-code ec2 --region $region \
    --query 'Quotas[?contains(QuotaName, `Elastic IP`)].{Name:QuotaName,Value:Value}' --output table
done
```

---

## 👤 Student Assignments — Username Only (Region is Fixed)

Every lab uniquifies AWS resource names by `var.username`. Students set their username once, in Lab 1, by running `lab01/setup.sh <username>` — the script saves `export TF_VAR_username="<username>"` to `~/.bashrc`. They never set a region (it defaults to us-east-2 in `variables.tf`):

```bash
bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh user1   # unique per student
source ~/.bashrc
# TF_VAR_aws_region is NOT needed — defaults to us-east-2
```

### Suggested assignment

Just hand out the username list:

| Student | Username |
|---------|----------|
| Alice   | user1    |
| Bob     | user2    |
| ...     | userN    |

**Username rules** — validation regex allows `[a-z0-9-]{3,20}` only. No uppercase, spaces, or dots.

### The env var is already persisted
`setup.sh` writes `TF_VAR_username` to `~/.bashrc`, so every new Cloud9 shell tab picks it up automatically. Every lab's **Lab Setup** has students confirm it:
- `echo $TF_VAR_username` should print their assigned name
- Prints nothing (e.g. in a shell opened before setup ran)? → `source ~/.bashrc`
- Wrong name? → re-run `bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <correct-username>` then `source ~/.bashrc`. Students should **not** `export` a different value by hand — every resource name includes it, and a mismatched name orphans resources from earlier labs.

---

## ☁️ Terraform Cloud Setup (Day 3)

For Labs 10–12, each student creates their own free-tier TFC organization, named `<username>-terraform-training`.

**Org names are globally unique across all of HCP Terraform.** If a student from a previous cohort still owns `user1-terraform-training`, the create fails with "name has already been taken". Lab 10 tells students to append a short suffix (initials or class date, e.g. `user1-terraform-training-jd`), write the actual name down, and use it in every `cloud { organization = ... }` block in Labs 10–12. At the end of the course, **ask students to delete their organization** (Organization **Settings** → **General** → **Delete this organization**) after their Lab 12 destroy has finished, so the name is free for the next cohort.

**Key point:** TFC remote runs do NOT inherit local `TF_VAR_*` env vars. Students must set the equivalents as workspace variables:

| Workspace variable     | Source             | Note                            |
|------------------------|--------------------|---------------------------------|
| `username`             | per-student        | from their assignment           |
| `aws_region`           | **`us-east-2`**    | the class deployment region     |
| `AWS_ACCESS_KEY_ID`    | env var, sensitive | the shared account's access key — you hand this out (READMEs say "provided by your instructor") |
| `AWS_SECRET_ACCESS_KEY`| env var, sensitive | matching secret                 |

For Lab 12, the README also has students add `CONFIRM_DESTROY=1` (env var, not sensitive). That variable came from older Terraform Cloud docs and is harmless, but it is **not** what gates destroys in current HCP Terraform: destroy plans require the workspace's **Settings** → **Destruction and Deletion** → **Allow destroy plans** toggle to be enabled. If a student can't queue the Lab 12 destroy, check that toggle first.

**Lab 11 workspaces are created from the CLI.** With `cloud { workspaces { tags = ["lab11"] } }`, `terraform init` prompts for a first workspace name, and `terraform workspace new lab11-development` / `lab11-staging` create the workspaces in HCP Terraform with the `lab11` tag attached (Terraform 1.9.8's cloud backend passes the configured tags on workspace create). Students then add variables in the UI. If a student created a workspace in the UI instead and it doesn't appear in `terraform workspace list`, have them add a key-only `lab11` tag in the UI, or delete it and re-create it with `terraform workspace new`.

**Pre-class prep:** have students sign up at https://app.terraform.io with a personal email, and verify their email before Day 3.

**GitHub PAT (Lab 12):** walk through token creation live — first-time users miss the "copy the token NOW" step.

**GitHub VCS connection in TFC (Lab 12):** Lab 12 Exercise 12.2 offers two paths; allow extra time (5–10 min) the first time students do it.
- **GitHub App** (preferred, Path A): **no organization-level step is needed** — students do *not* go to Organization Settings → Providers. During workspace creation they pick **Version control workflow** → **GitHub** → **GitHub.com**, authorize the HCP Terraform app for their GitHub account in the pop-up, and — if their repo isn't listed — choose **Add another organization** from the organization menu above the repo list to install the app on their personal account (all repositories, or selected repositories including the lab repo).
- **OAuth App** (Path B, **GitHub.com (Custom)**): configured once per TFC org at **Organization Settings → Providers**; students create a GitHub OAuth App and paste its Client ID + Client Secret into TFC. More moving parts; only use if the GitHub App path isn't available.

**"My push didn't trigger a run" (Lab 12) — most common causes, in order:**
1. **Pushing to a non-tracked branch.** A VCS workspace only acts on its tracked branch (`main`) and ignores pushes to other branches. In Exercise 12.4 the `feature/add-tags` push intentionally triggers nothing — the speculative plan comes from opening a **pull request** `main ← feature/add-tags`.
2. **GitHub App not granted access to the repo** (Path A) — app installed for *selected* repos that don't include the lab repo. Fix: GitHub → Settings → Applications → Installed GitHub Apps → Configure.
3. **Brand-new workspace** — HCP Terraform ignores VCS webhooks until the workspace's first run has been started manually (New run → Plan and apply). Lab 12 Step 6 tells students to do this.
4. Path B only: missing repo webhook / Callback URL mismatch between GitHub and TFC.

---

## ☁️ Cloud9 Environment Prep

All Cloud9 IDEs are provisioned in **`us-east-1`** with connection type **Secure Shell (SSH)**, not AWS Systems Manager (SSM). Lab 1, Exercise 1.1 tells students to choose SSH. Check this while they create their environments: the connection type can't be changed afterwards, so a wrong choice means deleting and recreating the environment.

In Lab 1, Exercise 1.2, students run `lab-exercises/lab01/setup.sh <username>`. The script grows the root EBS volume to 100 GB, installs Terraform 1.9.8, unzip, jq and git, starts Docker, and saves `TF_VAR_username` to `~/.bashrc`. It is safe to re-run.

**IAM:** the resize calls `ec2:DescribeInstances`, `ec2:DescribeVolumes`, `ec2:ModifyVolume` and `ec2:DescribeVolumesModifications` from the Cloud9 instance's credentials. If `ec2:ModifyVolume` is denied, the script prints a warning and continues on the original disk. Grant the permission, or resize the volumes yourself beforehand. Budget: 100 GB gp2/gp3 × N students for the length of the class.

Verify on a clean IDE (after `setup.sh` and `source ~/.bashrc`):
1. IDE is in `us-east-1` and its connection type is **SSH** (Cloud9 console → environment details)
2. `df -h /` shows ~100G, and `terraform version` reports `>= 1.9`
3. `docker --version` works (Lab 1 uses Docker)
4. `aws sts get-caller-identity` returns the shared account
5. `git --version` is installed
6. The repo is cloned to `~/environment/terraform_v2/`

If you clone elsewhere, every README's `cd ~/environment/terraform_v2/lab-exercises/labXX` line will fail.

---

## 🧹 End-of-Class Cleanup

Primary cleanup target is **`us-east-2`** (where all labs deployed). Sweep us-east-1 too in case TFC labs accidentally landed there. Sweep the expensive items first — **NAT gateways, Elastic IPs, and ALBs** bill by the hour (Labs 7–9), and leftover VPCs block the next class's quota.

Every student resource name starts with the student's username. The filters below assume the `userN` naming from the assignment table — set `PREFIX` to your class's common prefix (or loop over the username list):

```bash
PREFIX=user   # common username prefix for this class

for region in us-east-1 us-east-2; do
  echo "=== $region ==="

  # EC2 instances (all labs tag ManagedBy)
  aws ec2 describe-instances --region $region \
    --filters "Name=tag:ManagedBy,Values=Terraform,TerraformCloud" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table

  # NAT gateways (Labs 7, 8 staging/prod, 9) — most expensive leftover
  aws ec2 describe-nat-gateways --region $region \
    --filter "Name=state,Values=pending,available" \
    --query "NatGateways[?Tags[?Key=='Name' && starts_with(Value, '$PREFIX')]].[NatGatewayId,VpcId,Tags[?Key=='Name'].Value|[0]]" --output table

  # Elastic IPs (billed while allocated)
  aws ec2 describe-addresses --region $region \
    --query "Addresses[?Tags[?Key=='Name' && starts_with(Value, '$PREFIX')]].[AllocationId,PublicIp,AssociationId,Tags[?Key=='Name'].Value|[0]]" --output table

  # Application Load Balancers (Labs 7, 8 prod, 9)
  aws elbv2 describe-load-balancers --region $region \
    --query "LoadBalancers[?starts_with(LoadBalancerName, '$PREFIX')].[LoadBalancerName,VpcId]" --output table

  # Target groups
  aws elbv2 describe-target-groups --region $region \
    --query "TargetGroups[?starts_with(TargetGroupName, '$PREFIX')].[TargetGroupName,VpcId]" --output table

  # VPCs (Labs 7, 8, 9) — count against the 30-VPC quota
  aws ec2 describe-vpcs --region $region \
    --query "Vpcs[?Tags[?Key=='Name' && starts_with(Value, '$PREFIX')]].[VpcId,CidrBlock,Tags[?Key=='Name'].Value|[0]]" --output table
done

# S3 buckets are global — every lab's bucket name starts with the username
# (e.g. Lab 7's <username>-development-app-logs-<random>)
aws s3api list-buckets --query "Buckets[?starts_with(Name, '$PREFIX')].Name" --output table
```

Delete in dependency order: ALBs → target groups → instances → NAT gateways (wait for `deleted`) → release EIPs → VPCs (which also needs their subnets, IGWs, route tables, and non-default security groups gone) → S3 buckets. Easiest is to have each student run `terraform destroy` in the leftover lab directory; otherwise use `aws-nuke` scoped to the resource tags. Plan an hour.

---

## 📅 Day-of Schedule (Suggested)

The decks are **interleaved**: each module presents a short teaching segment, then the lab callout slide for the lab that uses it, then the next segment. Don't present a whole module up front — teach, run the lab, repeat.

| Day | Deck | Flow (each teaching segment ≈ 20–30 min, each lab 45 min) |
|-----|------|------------------------------------------------------------|
| 1   | Module 1 — Core Concepts (`module1_core_concepts.html`) | 9:00 course intro + teaching → **Lab 1** → teaching → **Lab 2** → lunch → teaching → **Lab 3** → teaching → **Lab 4** → teaching → **Lab 5** |
| 2   | Module 2 — Configuration and State (`module2_configuration.html`) | 9:00 teaching → **Lab 6** → teaching → **Lab 7** → lunch → teaching → **Lab 8** → teaching → **Lab 9** |
| 3   | Module 3 — Terraform Cloud (`module3_advanced.html`) | 9:00 teaching → **Lab 10** → teaching → **Lab 11** → lunch → teaching → **Lab 12** → course wrap-up and HCP Terraform org cleanup |

Add short breaks between blocks; Day 1 is the longest (five labs). Each lab is budgeted at 45 minutes. Lab 9 (largest local-state lab) and Lab 12 (VCS + TFC + GitHub setup) are the tightest; build in buffer.

---

## 🩹 Known Friction Points

- **Lab 4** S3 buckets sometimes take 2–3 min to fully delete; if a student hits `BucketAlreadyExists` on re-apply, they're waiting on AWS's name reservation timeout, not a Terraform bug.
- **Lab 5 and Labs 10–12** depend on the account's **default VPC in us-east-2** (the Lab 10–12 EC2 instances and security groups don't specify a VPC or subnet). If your shared account had its default VPC removed there, students get cryptic "no subnet specified" / "VPCIdNotSpecified" errors. Recreate with: `aws ec2 create-default-vpc --region us-east-2`.
- **Labs 7 and 9** ALB health checks need 2–3 minutes to mark targets healthy after first apply. Tell students to wait before `curl`-ing (Lab 9's README includes an `aws elbv2 describe-target-health` check).
- **Lab 10–12** `terraform login` writes a token to `~/.terraform.d/credentials.tfrc.json`. If Cloud9 recycles the home dir between sessions, students re-login.
- **Fallback to another region**: if us-east-2 hits a transient issue, any student can switch with `export TF_VAR_aws_region=us-east-1` (or us-west-1/us-west-2) and rerun. All four regions have raised quotas. For Labs 10–12 (remote runs), change the `aws_region` **workspace variable** instead — local `TF_VAR_*` exports don't reach TFC.
- **All AWS labs (2–12) use Amazon Linux 2023** for their EC2 instances (`al2023-ami-2023.*-x86_64`; Amazon Linux 2 reached end of support 2026-06-30). AL2023 enforces IMDSv2, so any `user_data` that reads instance metadata must fetch a session token first (see `lab08/user_data.sh`). `yum` still works (it's an alias for `dnf`); `amazon-linux-extras` does not exist on AL2023.
