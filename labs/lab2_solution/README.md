# Lab 2: Variables and Data Sources - Complete Solution

## 🎯 Overview
This directory contains the complete working solution for Lab 2: Terraform Variables and Data Sources.

## 📁 File Structure
```
lab2_solution/
├── README.md              # This file
├── main.tf               # Main configuration with resources
├── variables.tf          # Variable definitions
├── outputs.tf            # Output definitions
├── terraform.tfvars      # Variable values
└── terraform.tfvars.example  # Example values for other users
```

## 🚀 Quick Start

1. **Set your username environment variable:**
```bash
export TF_VAR_username="user1"  # Replace with your assigned username
```

2. **Initialize Terraform:**
```bash
terraform init
```

3. **Review the plan:**
```bash
terraform plan
```

4. **Apply the configuration:**
```bash
terraform apply
```

5. **View outputs:**
```bash
terraform output
terraform output -json
```

6. **Clean up resources:**
```bash
terraform destroy
```

## 📝 Key Learning Points

1. **Variable Types**: String, number, bool, list, map, object
2. **Variable Validation**: Input constraints and error messages
3. **Data Sources**: Query existing AWS resources
4. **Local Values**: Computed values and expressions
5. **Outputs**: Expose values for use and reference

## ⚠️ Important Notes

- Always set your username before running any commands
- Resources are prefixed with your username to prevent conflicts
- The AMI data source dynamically finds the latest Amazon Linux 2
- All resources are tagged with your username for identification