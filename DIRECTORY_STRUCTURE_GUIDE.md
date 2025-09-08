# Lab Directory Structure Guide

## 🎯 Overview
This guide explains the updated directory structure for all Terraform labs, which now use relative paths instead of home directory references.

---

## 📁 **Directory Creation Pattern**

### **Before (Old Pattern)**
```bash
cd ~
mkdir terraform-lab1
cd ~/terraform-lab1
```

### **After (New Pattern)**
```bash
mkdir terraform-lab1
cd terraform-lab1
```

---

## 🗂️ **Lab Directory Structure**

Each lab creates its directory in the current working location:

```
Current Working Directory/
├── terraform-lab1/           # Lab 1 files
├── terraform-lab2/           # Lab 2 files  
├── backend-setup/            # Lab 5 backend setup
├── terraform-lab6-enterprise-state/  # Lab 6 files
├── terraform-lab7-advanced/ # Lab 7 files
├── terraform-lab8-vpc/      # Lab 8 files
├── terraform-cloud-intro/   # Lab 9 files
├── terraform-cloud-teams/   # Lab 10 files
├── terraform-policies-registry/  # Lab 11 files
└── terraform-final-project/ # Lab 12 files
```

---

## ✅ **Benefits of Relative Paths**

### **Flexibility**
- ✅ **Any Working Directory**: Students can work from any location
- ✅ **No Home Pollution**: Doesn't clutter the home directory
- ✅ **Easy Organization**: Keep all labs in a dedicated training folder
- ✅ **Path Independence**: Works regardless of user home directory structure

### **Better Organization**
```bash
# Recommended: Create a training directory first
mkdir terraform-training
cd terraform-training

# Now all labs will be created under terraform-training/
mkdir terraform-lab1        # Creates: terraform-training/terraform-lab1/
mkdir terraform-lab2        # Creates: terraform-training/terraform-lab2/
# etc...
```

---

## 🧪 **Directory Validation Script**

Create this script to verify your lab setup:

```bash
#!/bin/bash
# validate-lab-directories.sh
# Run this to check your lab directory structure

echo "=== Lab Directory Structure Validation ==="
echo ""

echo "📍 Current Location: $(pwd)"
echo ""

# List all lab directories
LABS=(
    "terraform-lab1"
    "terraform-lab2" 
    "terraform-lab3"
    "terraform-lab4"
    "backend-setup"
    "terraform-lab6-enterprise-state"
    "terraform-lab7-advanced"
    "terraform-lab8-vpc"
    "terraform-cloud-intro"
    "terraform-cloud-teams"
    "terraform-policies-registry"
    "terraform-final-project"
)

echo "🔍 Checking for lab directories:"
for lab in "${LABS[@]}"; do
    if [ -d "$lab" ]; then
        echo "✅ Found: $lab/"
        # Count Terraform files
        tf_files=$(find "$lab" -name "*.tf" 2>/dev/null | wc -l)
        if [ $tf_files -gt 0 ]; then
            echo "   📄 Terraform files: $tf_files"
        fi
    else
        echo "❌ Missing: $lab/"
    fi
done

echo ""
echo "📊 Summary:"
existing_dirs=$(find . -maxdepth 1 -name "terraform-*" -type d | wc -l)
echo "Terraform lab directories found: $existing_dirs"

if [ $existing_dirs -gt 0 ]; then
    echo "✅ Lab directories detected in current location"
else
    echo "ℹ️  No lab directories found - you'll create them as you progress"
fi

echo ""
echo "💡 Tip: All lab directories will be created in your current location"
echo "Consider organizing with: mkdir terraform-training && cd terraform-training"
```

---

## 📋 **Lab-Specific Directory Commands**

### **Lab 1: First Configuration**
```bash
mkdir terraform-lab1
cd terraform-lab1
```

### **Lab 2: Variables and Data**
```bash
mkdir terraform-lab2
cd terraform-lab2
```

### **Lab 3: Dependencies and Lifecycle**
```bash
mkdir terraform-lab3
cd terraform-lab3
```

### **Lab 4: Modules**
```bash
mkdir terraform-lab4
cd terraform-lab4
```

### **Lab 5: Remote State**
```bash
mkdir backend-setup
cd backend-setup
```

### **Lab 6: Enterprise State Management**
```bash
mkdir terraform-lab6-enterprise-state
cd terraform-lab6-enterprise-state
```

### **Lab 7: Advanced Patterns**
```bash
mkdir terraform-lab7-advanced
cd terraform-lab7-advanced
```

### **Lab 8: Advanced Networking**
```bash
mkdir terraform-lab8-vpc
cd terraform-lab8-vpc
```

### **Lab 9: Terraform Cloud Intro**
```bash
mkdir terraform-cloud-intro
cd terraform-cloud-intro
```

### **Lab 10: Teams and Workspaces**
```bash
mkdir terraform-cloud-teams
cd terraform-cloud-teams
```

### **Lab 11: Policies and Registry**
```bash
mkdir terraform-policies-registry
cd terraform-policies-registry
```

### **Lab 12: Final Project**
```bash
mkdir terraform-final-project
cd terraform-final-project
```

---

## 🔧 **Troubleshooting**

### **Issue: Lab directories in wrong location**
```bash
# If you accidentally created in home directory
ls ~/terraform-*  # Check what's in home

# Move to organized location
mkdir terraform-training
mv ~/terraform-* terraform-training/
cd terraform-training
```

### **Issue: Can't find previous lab work**
```bash
# Find all terraform directories
find ~ -name "terraform-*" -type d 2>/dev/null

# Or search for .tf files
find ~ -name "*.tf" 2>/dev/null
```

### **Issue: Permission problems**
```bash
# Ensure current directory is writable
ls -ld $(pwd)

# If not writable, change to your user directory
cd ~
mkdir terraform-training
cd terraform-training
```

---

## ✅ **Best Practices**

### **Organization Strategy**
1. ✅ **Create training folder first**: `mkdir terraform-training && cd terraform-training`
2. ✅ **Stay in training folder**: All labs created under this location
3. ✅ **Use relative paths**: No need for full paths or `~/` references
4. ✅ **Keep labs separate**: Each lab in its own directory

### **Navigation Tips**
```bash
# Navigate between labs
cd ../terraform-lab2     # From lab1 to lab2
cd ../../terraform-lab5  # Go up two levels then into lab5

# Return to training root
cd ~/terraform-training  # If you used organized approach
```

### **Cleanup Strategy**
```bash
# Clean up a specific lab
rm -rf terraform-lab1

# Clean up all labs
rm -rf terraform-*

# Or move completed labs to archive
mkdir completed-labs
mv terraform-lab[1-8] completed-labs/
```

---

## 🎯 **Summary**

The updated lab structure provides:
- ✅ **More Flexibility** - Work from any directory
- ✅ **Better Organization** - Keep labs together
- ✅ **Cleaner Paths** - No home directory pollution
- ✅ **Easier Navigation** - Relative paths are shorter
- ✅ **Consistent Experience** - Same commands work for everyone

Students can now create their lab environment wherever they prefer while maintaining clean organization and easy navigation between labs.