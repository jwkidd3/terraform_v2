# Instructor Pre-Flight Checklist

Read this BEFORE class day. The course assumes one shared AWS account with N students (typically 12–27).

**Deployment topology:**
- **Cloud9 IDEs all live in `us-east-1`** (instructor-managed).
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

Every lab uniquifies AWS resource names by `var.username`. Students must set their username, but not their region (region defaults to us-east-2 in `variables.tf`):

```bash
export TF_VAR_username="user1"           # unique per student
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

### Persist the env var (optional)
For students opening many shell tabs:
```bash
echo 'export TF_VAR_username="user1"' >> ~/.bashrc
```

Remind students before every lab:
- `echo $TF_VAR_username` should print their assigned name
- Re-export after opening a new Cloud9 shell tab (env vars don't persist across tabs unless in `~/.bashrc`)

---

## ☁️ Terraform Cloud Setup (Day 3)

For Labs 10–12, each student creates their own free-tier TFC organization.

**Key point:** TFC remote runs do NOT inherit local `TF_VAR_*` env vars. Students must set the equivalents as workspace variables:

| Workspace variable     | Source             | Note                            |
|------------------------|--------------------|---------------------------------|
| `username`             | per-student        | from their assignment           |
| `aws_region`           | **`us-east-2`**    | the class deployment region     |
| `AWS_ACCESS_KEY_ID`    | env var, sensitive | the shared account's access key |
| `AWS_SECRET_ACCESS_KEY`| env var, sensitive | matching secret                 |

For Lab 12 specifically, also add `CONFIRM_DESTROY=1` (env var, not sensitive) so the destroy step at the end of the lab works.

**Pre-class prep:** have students sign up at https://app.terraform.io with a personal email, and verify their email before Day 3.

**GitHub PAT (Lab 12):** walk through token creation live — first-time users miss the "copy the token NOW" step.

---

## ☁️ Cloud9 Environment Prep

All Cloud9 IDEs are provisioned in **`us-east-1`**. Verify on a clean IDE:
1. IDE is in `us-east-1` (check the URL or Cloud9 console)
2. `terraform version` reports `>= 1.9`
3. `docker --version` works (Lab 1 uses Docker)
4. `aws sts get-caller-identity` returns the shared account
5. `git --version` is installed
6. The repo is cloned to `~/environment/terraform_v2/`

If you clone elsewhere, every README's `cd ~/environment/terraform_v2/lab-exercises/labXX` line will fail.

---

## 🧹 End-of-Class Cleanup

Primary cleanup target is **`us-east-2`** (where all labs deployed). Sweep us-east-1 too in case TFC labs accidentally landed there:

```bash
for region in us-east-1 us-east-2; do
  echo "=== $region ==="
  aws ec2 describe-instances --region $region \
    --filters "Name=tag:ManagedBy,Values=Terraform,TerraformCloud" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table
done

# S3 buckets are global — list and look for student-prefixed bucket names
aws s3api list-buckets --query 'Buckets[?contains(Name, `-bucket`)].Name' --output table
```

Then manually destroy or use `aws-nuke` scoped to the resource tags. Plan an hour.

---

## 📅 Day-of Schedule (Suggested)

| Day | Time | Activity |
|-----|------|----------|
| 1   | 9:00 | Module 1 presentation (1h) — labs 1–5 (45 min each, 30 min break) |
| 2   | 9:00 | Module 2 presentation (1h) — labs 6–9 |
| 3   | 9:00 | Module 3 presentation (1h) — labs 10–12 |

Each lab is budgeted at 45 minutes. Lab 9 (largest local-state lab) and Lab 12 (VCS + TFC + GitHub setup) are the tightest; build in buffer.

---

## 🩹 Known Friction Points

- **Lab 4** S3 buckets sometimes take 2–3 min to fully delete; if a student hits `BucketAlreadyExists` on re-apply, they're waiting on AWS's name reservation timeout, not a Terraform bug.
- **Lab 5** modules depend on the account's **default VPC in us-east-2**. If your shared account had its default VPC removed there, students get cryptic "no subnet specified" errors. Recreate with: `aws ec2 create-default-vpc --region us-east-2`.
- **Lab 7/8/9** ALB health checks need 2–3 minutes to mark targets healthy after first apply. Tell students to wait before `curl`-ing.
- **Lab 10–12** `terraform login` writes a token to `~/.terraform.d/credentials.tfrc.json`. If Cloud9 recycles the home dir between sessions, students re-login.
- **Fallback to another region**: if us-east-2 hits a transient issue, any student can switch with `export TF_VAR_aws_region=us-east-1` (or us-west-1/us-west-2) and rerun. All four regions have raised quotas.
