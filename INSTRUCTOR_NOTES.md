# Instructor Pre-Flight Checklist

Read this BEFORE class day. The course assumes one shared AWS account with N students (typically 12–20) spread across **multiple AWS regions**, each on their own Cloud9 IDE.

---

## 🚨 AWS Service Quotas (DO THIS FIRST)

Default per-region AWS quotas (5 VPCs, 5 EIPs, 5 NAT, 5 IGW) will block most students in Labs 7, 8, and 9.

**Multi-region strategy** — pick one of these:

### Option A: Spread students evenly, modest quota bumps
If you assign, say, 5 students per region across 4 regions, each region needs quotas raised to **~10** (2× headroom for leftover resources between labs).

### Option B: All students in one region, big quota bumps
Cleaner for support but requires raising quotas in that one region to **~30+** for 20 students.

### Quotas to raise (per region you're using)

| Service | Quota name | Default | Raise to (per region, for N students) |
|---------|------------|---------|---------------------------------------|
| VPC | VPCs per Region | 5 | **2 × N** |
| VPC | NAT Gateways per AZ | 5 | **2 × N** |
| EC2 | EC2-VPC Elastic IPs | 5 | **2 × N** |
| EC2 | Internet gateways per Region | 5 | **2 × N** |
| EC2 | Running On-Demand Standard vCPUs | varies | **10 × N** (covers t3.micro/small fleet with margin) |

Submit via **AWS Console → Service Quotas → AWS services → [select service] → Request quota increase**. Quota increases typically approve in **2–24 hours**; EIP and NAT raises sometimes need a support case — do them now if class is tomorrow.

### Verify per-region quotas
```bash
for region in us-east-1 us-east-2 us-west-2 eu-west-1; do
  echo "=== $region ==="
  aws service-quotas list-service-quotas --service-code vpc --region $region \
    --query 'Quotas[?contains(QuotaName, `VPCs`) || contains(QuotaName, `NAT`) || contains(QuotaName, `Elastic IP`)].{Name:QuotaName,Value:Value}'
done
```

---

## 👤 Student Assignments — Username AND Region

Every lab uniquifies AWS resource names by `var.username`. Every student must set BOTH:

```bash
export TF_VAR_username="user1"           # unique per student
export TF_VAR_aws_region="us-east-1"     # assigned by instructor
```

`terraform.tfvars` files no longer hardcode either value — these env vars are the single source of truth for Labs 1–9. (For TFC labs 10–12, students set the same two values as **workspace variables** because remote TFC runs don't inherit local env vars.)

### Suggested assignment format

Hand out a CSV or table at the start of Day 1:

| Student name | Username | Region    |
|--------------|----------|-----------|
| Alice        | user1    | us-east-1 |
| Bob          | user2    | us-east-1 |
| ...          | userN    | ...       |

**Username rules** — validation regex allows `[a-z0-9-]{3,20}` only. Avoid uppercase, spaces, dots.

**Region rules** — pick from regions where you've raised quotas. Stick to mainstream regions (us-east-1, us-east-2, us-west-2, eu-west-1) — exotic regions sometimes lack AMIs or service availability.

Remind students at the start of every lab:
1. Confirm `echo $TF_VAR_username` and `echo $TF_VAR_aws_region` print their assigned values
2. Re-export after opening a new Cloud9 shell tab (env vars don't persist across tabs unless added to `~/.bashrc`)

### Persist the env vars (optional)
For students opening many shell tabs:
```bash
cat >> ~/.bashrc <<'EOF'
export TF_VAR_username="user1"
export TF_VAR_aws_region="us-east-1"
EOF
```

---

## ☁️ Terraform Cloud Setup (Day 3)

For Labs 10–12, each student creates their own free-tier TFC organization.

**Key point:** TFC remote runs do NOT inherit local `TF_VAR_*` env vars. Students must set the equivalents as workspace variables:

| Workspace variable | Source         | Note                            |
|--------------------|----------------|---------------------------------|
| `username`         | per-student    | from their assignment           |
| `aws_region`       | per-student    | from their assignment           |
| `AWS_ACCESS_KEY_ID`| env var, sensitive | the shared account's access key |
| `AWS_SECRET_ACCESS_KEY` | env var, sensitive | matching secret             |

For Lab 12 specifically, also add `CONFIRM_DESTROY=1` (env var, not sensitive) so the destroy step at the end of the lab works.

**Pre-class prep:** have students sign up at https://app.terraform.io with a personal email (not corporate SSO they'll lose access to after class), and verify their email before Day 3.

**GitHub PAT (Lab 12):** walk through token creation live — first-time users miss the "copy the token NOW" step.

---

## ☁️ Cloud9 Environment Prep

Before class starts, verify on a clean Cloud9 IDE:
1. `terraform version` reports `>= 1.9`
2. `docker --version` works (Lab 1 uses Docker)
3. `aws sts get-caller-identity` returns the shared account
4. `git --version` is installed
5. The repo is cloned to `~/environment/terraform_v2/`

If you clone elsewhere, every README's `cd ~/environment/terraform_v2/lab-exercises/labXX` line will fail.

---

## 🧹 End-of-Class Cleanup

The shared AWS account WILL accumulate leftover resources from students who skip cleanup. After Day 3, sweep every region you used:

```bash
for region in us-east-1 us-east-2 us-west-2 eu-west-1; do
  echo "=== $region ==="
  aws ec2 describe-instances --region $region \
    --filters "Name=tag:ManagedBy,Values=Terraform,TerraformCloud" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table
done

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
- **Lab 5** modules depend on the account's **default VPC** in the student's region. If your shared account had its default VPC removed in some regions, students there get cryptic "no subnet specified" errors. Recreate with: `aws ec2 create-default-vpc --region <region>`.
- **Lab 7/8/9** ALB health checks need 2–3 minutes to mark targets healthy after first apply. Tell students to wait before `curl`-ing.
- **Lab 10–12** `terraform login` writes a token to `~/.terraform.d/credentials.tfrc.json`. If Cloud9 recycles the home dir between sessions, students re-login.
- **Region-specific AMIs**: The labs use `data.aws_ami` with filter `amzn2-ami-hvm-*-x86_64-gp2` — Amazon Linux 2 is available in every commercial region, so this is safe. If you assign students to GovCloud or a brand-new region, verify the AMI filter still matches before class.
