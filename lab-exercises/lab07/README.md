# Lab 7: Working with Terraform Registry Modules
**Duration:** 45 minutes  
**Difficulty:** Intermediate  
**Day:** 2  
**Environment:** AWS Cloud9

---

## 🎯 **Learning Objectives**
By the end of this lab, you will be able to:
- Use Terraform Registry modules in your configurations
- Combine multiple registry modules to build infrastructure
- Configure module inputs and consume module outputs
- Apply module versioning and best practices
- Build a simple multi-tier application using proven modules

---

## 📋 **Prerequisites**
- Completion of Labs 2-6
- Understanding of module basics from Lab 5
- State management concepts from Lab 6
- Basic VPC networking knowledge

---

## 🛠️ **Lab Setup**

### Set Your Username
```bash
# IMPORTANT: Replace "user1" with your assigned username
export TF_VAR_username="user1"
echo "Your username: $TF_VAR_username"
```

---

## 🏗️ **Exercise 7.1: VPC and Security with Registry Modules (25 minutes)**

### Step 1: Create Lab Directory
```bash
cd ~/environment
mkdir terraform-lab7
cd terraform-lab7
```

### Step 2: Basic VPC Infrastructure
We'll use the popular VPC module from the Terraform Registry to create our networking foundation.

[Content continues with the full lab content from the source file...]

---

## 🧹 **Cleanup**
```bash
terraform destroy
```

---

## 🎓 **Next Steps**
In **Lab 8**, we'll explore **multi-environment patterns** and **workspace management** to handle different deployment stages effectively.

**Key topics coming up:**
- Terraform workspaces
- Environment-specific configurations
- Variable precedence patterns
- Deployment strategies