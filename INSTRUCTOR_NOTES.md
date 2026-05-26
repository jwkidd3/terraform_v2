# Instructor Pre-Flight Checklist

Read this BEFORE class day. The course assumes one shared AWS account with N students (typically 12–20), each on their own Cloud9 IDE.

---

## 🚨 AWS Service Quotas (DO THIS FIRST)

The default per-region AWS quotas will block most students in Labs 7, 8, and 9. Submit quota increases at least **48 hours before class** via the AWS Service Quotas console.

For **us-east-1** (or whatever region you assign), in the shared AWS account, raise:

| Service        | Quota                                | Default | Raise to (for ~20 students) |
|----------------|--------------------------------------|---------|-----------------------------|
| VPC            | VPCs per Region                      | 5       | 30                          |
| VPC            | NAT Gateways per AZ                  | 5       | 30                          |
| EC2            | EC2-VPC Elastic IPs                  | 5       | 30                          |
| EC2            | Running On-Demand Standard vCPUs     | varies  | 200+ (covers t3.micro/small fleet) |
| EC2            | Internet gateways per Region         | 5       | 30                          |

Without these increases:
- Lab 7 (registry modules: VPC + NAT) — first ~5 students succeed, rest hit `VpcLimitExceeded` or `AddressLimitExceeded`.
- Lab 8 (multi-env: VPC + NAT) — same.
- Lab 9 (2-tier VPC: VPC + NAT + EIP + ALB) — same.

You can verify current limits via:
```bash
aws service-quotas list-service-quotas --service-code vpc --region us-east-1 \
  --query 'Quotas[?contains(QuotaName, `VPCs`) || contains(QuotaName, `NAT`) || contains(QuotaName, `Elastic IP`)].{Name:QuotaName,Value:Value}'
```

---

## 👤 Student Username Assignments

Every lab uniquifies AWS resource names by `var.username`. Each student must use a **distinct** username, set via:

```bash
export TF_VAR_username="user1"
```

`terraform.tfvars` files no longer hardcode `username` — students rely entirely on `TF_VAR_username`.

**Suggested format:** `user1`, `user2`, ... `userN`. Avoid uppercase, spaces, and very long names (validation regex allows `[a-z0-9-]{3,20}` only).

Hand out the assignment list at the start of Day 1 and remind students to:
1. `export TF_VAR_username="<their>"` in every new shell tab they open
2. Verify with `echo $TF_VAR_username` before any `terraform apply`

---

## ☁️ Terraform Cloud Setup (Day 3)

For Labs 10–12 each student creates their own free-tier TFC organization. Have them:
1. Sign up at https://app.terraform.io with a personal email (not a corporate SSO account they'll lose access to after class)
2. Verify their email before Day 3 — verification emails sometimes go to spam

**GitHub PAT (Lab 12):** students need a Personal Access Token with `repo` scope. Walk through token creation live — first-time users frequently miss the "copy the token NOW" step.

**TFC ↔ GitHub OAuth (Lab 12):** the first student to connect TFC to GitHub triggers an org-level OAuth handshake. This is per-student (each has their own TFC org) and takes 1–2 minutes the first time.

---

## ☁️ Cloud9 Environment Prep

Before class starts, verify on a clean Cloud9 IDE:
1. `terraform version` reports `>= 1.9`
2. `docker --version` works (Lab 1 uses Docker)
3. `aws sts get-caller-identity` returns the shared account (no SSO required mid-lab)
4. `git --version` is installed (it is on Amazon Linux 2)
5. The repo is cloned to `~/environment/terraform_v2/`

If you've cloned the course repo elsewhere, every README's `cd ~/environment/terraform_v2/lab-exercises/labXX` line will fail. Fix the path or fix the readme.

---

## 🧹 End-of-Class Cleanup

The shared AWS account WILL accumulate leftover resources from students who skip cleanup. After Day 3 ends, run:

```bash
# As an admin, list anything still tagged from labs
aws ec2 describe-instances --filters "Name=tag:ManagedBy,Values=Terraform,TerraformCloud" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table

aws s3api list-buckets --query 'Buckets[?contains(Name, `-bucket`)].Name' --output table
```

Then manually destroy or use `aws-nuke` scoped to the resource tags. Plan an hour for this.

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
- **Lab 5** modules depend on the account's **default VPC**. If your shared account had its default VPC removed, students get cryptic "no subnet specified" errors. Re-create the default VPC: `aws ec2 create-default-vpc` (per region).
- **Lab 7/8/9** ALB health checks need 2–3 minutes to mark targets healthy after first apply. Students who `curl` immediately see 503s. Tell them to wait.
- **Lab 10–12** `terraform login` writes a token to `~/.terraform.d/credentials.tfrc.json`. If Cloud9 recycles the home dir between sessions (rare but happens), students need to re-login.
