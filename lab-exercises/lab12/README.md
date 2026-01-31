# Lab 12: VCS-Driven Terraform Cloud with GitHub Integration
**Duration:** 45 minutes
**Difficulty:** Advanced
**Day:** 3
**Environment:** GitHub + Terraform Cloud + AWS

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Connect a GitHub repository to Terraform Cloud for VCS-driven workflows
- Configure Terraform Cloud to automatically pull and build from GitHub
- Set up webhook-triggered runs when code is pushed to GitHub
- Understand VCS-driven workspace configuration and best practices
- Implement a pull-based deployment model with Terraform Cloud

---

## 📋 **Prerequisites**
- Completion of Labs 10-11 (Terraform Cloud fundamentals)
- GitHub account with repository creation permissions
- Terraform Cloud account and organization
- Basic understanding of version control with Git

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🔗 **Exercise 12.1: Prepare Infrastructure Code in GitHub (10 minutes)**

### Step 1: Create GitHub Repository
1. Go to GitHub: https://github.com
2. Click **New Repository**
3. Repository name: `terraform-vcs-lab12-{username}` (replace with your username)
4. Description: "VCS-Driven Terraform Cloud Lab 12 - Infrastructure pulled and built from GitHub"
5. Set to **Public** (required for Terraform Cloud free tier)
6. Initialize with README: **checked**
7. Click **Create repository**

### Step 2: Clone and Populate Repository
```bash
cd ~/environment
git clone https://github.com/YOUR_USERNAME/terraform-vcs-lab12-{username}.git
cd terraform-vcs-lab12-{username}
```

### Step 3: Add Terraform Configuration Files
Copy the lab files from the lab12 directory to your repository:

```bash
# Copy main infrastructure files
cp ~/environment/lab-exercises/lab12/main.tf .
cp ~/environment/lab-exercises/lab12/variables.tf .
cp ~/environment/lab-exercises/lab12/outputs.tf .
cp ~/environment/lab-exercises/lab12/user_data.sh .
cp ~/environment/lab-exercises/lab12/terraform.tfvars .

# Update your username in terraform.tfvars
echo 'username = "YOUR_USERNAME"' > terraform.tfvars
echo 'environment = "gitops"' >> terraform.tfvars
echo 'app_version = "v1.0.0"' >> terraform.tfvars
```

### Step 4: Prepare Repository for Terraform Cloud
Remove the placeholder values and prepare for VCS-driven workflow:

**Edit main.tf** - Update the cloud block:
```hcl
  cloud {
    organization = "YOUR_TFC_ORG_NAME"  # You'll update this in the next exercise

    workspaces {
      name = "vcs-lab12-YOUR_USERNAME"  # You'll update this in the next exercise
    }
  }
```

### Step 5: Commit Initial Code
```bash
git add .
git commit -m "Initial Terraform configuration for VCS-driven workflow

- Add 3-tier web application infrastructure
- Configure for Terraform Cloud VCS integration
- Prepare for automated GitHub pulls and builds"

git push origin main
```

---

## ☁️ **Exercise 12.2: Connect GitHub Repository to Terraform Cloud (15 minutes)**

### Step 1: Create VCS-Driven Workspace
1. Go to Terraform Cloud: https://app.terraform.io
2. In your organization, click **New Workspace**
3. Choose **Version control workflow** (this is key!)
4. Connect to **GitHub**
5. If first time: Click **Authorize** to allow Terraform Cloud to access GitHub
6. Select your `terraform-vcs-lab12-{username}` repository from the list
7. Workspace name: `vcs-lab12-{username}`
8. Description: "VCS-driven workspace demonstrating GitHub integration"
9. Click **Create workspace**

### Step 2: Understand VCS Integration
Notice what Terraform Cloud automatically configured:
- **Repository Connection**: Direct link to your GitHub repo
- **Webhook**: Automatic webhook created in GitHub (check Settings → Webhooks)
- **Pull Access**: Terraform Cloud can pull code from your repository
- **Build Triggers**: Runs will trigger on Git pushes automatically

### Step 3: Configure Workspace for VCS Operations
1. Go to **Settings** → **General**
2. **Execution Mode**: Remote (runs in Terraform Cloud)
3. **Apply Method**: Manual apply (requires approval)
4. **Terraform Working Directory**: Leave blank (uses repo root)
5. **VCS Triggers**:
   - **Automatic speculative plans**: Enabled
   - **Auto apply**: Disabled (for safety)
6. **VCS Branch**: `main` (pulls from main branch)

### Step 4: Configure Environment Variables
Add these **Environment Variables** (for AWS access):
- `AWS_ACCESS_KEY_ID` (mark as sensitive)
- `AWS_SECRET_ACCESS_KEY` (mark as sensitive)
- `AWS_DEFAULT_REGION` = `us-east-2`

### Step 5: Update Repository Configuration
Now that you have your workspace name, update your repository:

1. Go back to your local repository
2. Edit `main.tf` and update the cloud block:
```hcl
  cloud {
    organization = "YOUR_ACTUAL_ORG_NAME"  # Use your real org name

    workspaces {
      name = "vcs-lab12-YOUR_USERNAME"  # Use your real workspace name
    }
  }
```

3. Commit and push the change:
```bash
git add main.tf
git commit -m "Update Terraform Cloud configuration with actual workspace details"
git push origin main
```

---

## 🚀 **Exercise 12.3: Test VCS-Driven Builds and Deployments (15 minutes)**

### Step 1: Watch Initial Automatic Build
1. After pushing your configuration update in the previous step, go to your Terraform Cloud workspace
2. You should see a **new run triggered automatically** by the Git push
3. Click on the run to observe:
   - **Source**: Shows it was triggered by GitHub webhook
   - **Plan Phase**: Terraform Cloud pulled your code and ran `terraform plan`
   - **Configuration**: Code was fetched directly from your GitHub repository

### Step 2: Approve and Deploy
1. Review the **Plan** output showing your infrastructure
2. Click **Confirm & Apply** to deploy
3. Watch the **Apply** phase where Terraform Cloud builds your infrastructure
4. Note that this is running remotely using code pulled from GitHub

### Step 3: Verify VCS-Driven Deployment
Check your deployment:
1. Go to **States** → **Latest** → **Outputs** in Terraform Cloud
2. Find the ALB DNS name
3. Visit `http://[ALB-DNS-NAME]` to see your application
4. The web page should show it was deployed via VCS-driven workflow

### Step 4: Demonstrate Code-to-Infrastructure Pipeline
Make a change to test the VCS integration:

**Edit terraform.tfvars:**
```hcl
username = "YOUR_USERNAME"  # Your actual username
environment = "gitops"
app_version = "v1.1.0"  # Bump version
desired_instances = 3    # Scale up
```

**Commit and push:**
```bash
git add terraform.tfvars
git commit -m "Scale infrastructure and update app version via VCS

- Increase desired_instances from 2 to 3 (auto scaling)
- Update app_version to v1.1.0
- Demonstrate VCS-triggered infrastructure changes"

git push origin main
```

### Step 5: Watch Automatic VCS-Triggered Build
1. **Immediately** go to your Terraform Cloud workspace
2. Within seconds, you should see a **new run appear automatically**
3. This demonstrates the webhook integration:
   - GitHub detected your push
   - Webhook notified Terraform Cloud
   - Terraform Cloud pulled the latest code
   - New plan/apply cycle initiated automatically
4. Review the plan showing your scaling changes
5. Approve the apply to see VCS-driven infrastructure changes

---

## 🔄 **Exercise 12.4: Advanced VCS Features and Branch Workflows (5 minutes)**

### Step 1: Explore VCS Settings
1. Go to **Settings** → **Version Control** in your workspace
2. Review the VCS configuration:
   - **Repository**: Shows your connected GitHub repo
   - **Branch**: Currently building from `main`
   - **Webhook URL**: The endpoint GitHub calls
   - **Include submodules**: For complex repository structures

### Step 2: Test Branch-Based Planning
Create a feature branch to see speculative plans:
```bash
# Create feature branch (won't trigger deployments)
git checkout -b feature/add-monitoring

# Add a monitoring resource to main.tf
```

**Add to the end of main.tf:**
```hcl
# CloudWatch Alarm for monitoring VCS-driven deployments
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Monitors CPU for VCS-deployed instances"
  alarm_actions       = []

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  tags = local.common_tags
}
```

```bash
git add main.tf
git commit -m "Add monitoring for VCS-driven infrastructure

- CloudWatch alarm for high CPU utilization
- Demonstrates branch-based planning workflow
- No deployment until merged to main"

git push origin feature/add-monitoring
```

### Step 3: Observe Speculative Planning
1. Go to your Terraform Cloud workspace
2. You should see a **speculative plan** was created
3. This shows what would happen if the branch were merged
4. **Key Point**: No actual infrastructure changes because it's not the main branch

### Step 4: Understand VCS-Driven vs CLI-Driven
Compare the two approaches:

**VCS-Driven (what you just learned):**
- ✅ Code stored in GitHub
- ✅ Terraform Cloud pulls and builds automatically
- ✅ Webhook triggers on Git push
- ✅ Team collaboration through Git workflows
- ✅ Infrastructure versioned with application code

**CLI-Driven (Labs 10-11):**
- Code on local machine
- Manual terraform commands
- Direct API calls to Terraform Cloud
- Good for testing and development

---

## 🎯 **Lab Summary**

### What You Accomplished
✅ **VCS-Driven Workflow** - Connected GitHub repository to Terraform Cloud
✅ **Automatic Code Pulling** - Terraform Cloud pulls and builds from GitHub automatically
✅ **Webhook Integration** - GitHub webhooks trigger Terraform Cloud runs
✅ **Production Infrastructure** - 3-tier web application deployed via VCS workflow
✅ **Branch-Based Planning** - Speculative plans for feature branches
✅ **Team Collaboration** - Infrastructure code shared through Git repository

### Key VCS-Driven Concepts Learned
- **Repository Integration**: Terraform Cloud connects directly to GitHub
- **Automatic Builds**: Git pushes trigger infrastructure builds automatically
- **Code Pulling**: Terraform Cloud fetches code from repository for each run
- **Webhook Automation**: GitHub notifies Terraform Cloud of code changes
- **Branch Workflows**: Main branch deploys, feature branches create plans only

### VCS-Driven Benefits Demonstrated
- **Centralized Code**: All infrastructure code stored in version control
- **Automatic Triggers**: No manual intervention needed for deployments
- **Team Collaboration**: Multiple developers can work on infrastructure
- **Change Tracking**: Git history provides complete audit trail
- **Branch Protection**: Test changes in branches before merging

### Technical Integration Points
- GitHub repository containing Terraform configuration
- Terraform Cloud workspace connected to specific repository
- Webhook automatically created in GitHub settings
- Automatic code pulling and building on every push
- Speculative planning for non-main branches

---

## 🧹 **Cleanup**
```bash
# Destroy infrastructure via Terraform Cloud UI
# 1. Go to your workspace in Terraform Cloud
# 2. Click "Actions" → "Start new run"
# 3. Choose "Destroy" as the plan type
# 4. Confirm the destroy

# Clean up local repository (optional)
cd ~/environment
rm -rf terraform-vcs-lab12-{username}

# Note: Keep GitHub repository to showcase VCS-driven workflow
```

---

## 🎓 **Course Conclusion**
Congratulations! You've completed all 12 labs and now have expertise in:

**✅ Terraform Fundamentals** (Labs 1-5)
**✅ Advanced Configuration** (Labs 6-9)
**✅ Terraform Cloud Integration** (Labs 10-11)
**✅ VCS-Driven Infrastructure** (Lab 12)

**Key Skills Mastered:**
- Infrastructure as Code with Terraform
- Multi-tier AWS architecture design
- Remote state management with Terraform Cloud
- VCS-driven workflows with GitHub integration
- Production-ready infrastructure automation

**Portfolio-Ready Projects:**
- GitHub repository with production infrastructure code
- VCS-driven Terraform Cloud workspace
- Complete infrastructure automation pipeline

You're now equipped to implement Infrastructure as Code in any organization using industry-standard VCS-driven workflows!