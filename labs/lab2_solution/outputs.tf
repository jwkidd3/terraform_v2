# Lab 2: Variables and Data Sources - Complete Solution
# outputs.tf - All output definitions

# ===========================================
# ACCOUNT AND REGION INFORMATION
# ===========================================

output "account_info" {
  description = "AWS account information"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    caller_arn = data.aws_caller_identity.current.arn
    user_id    = data.aws_caller_identity.current.user_id
    region     = data.aws_region.current.name
  }
}

output "availability_zones" {
  description = "Available AZs in the current region"
  value       = data.aws_availability_zones.available.names
}

# ===========================================
# AMI INFORMATION
# ===========================================

output "ami_info" {
  description = "Information about the AMI used"
  value = {
    id            = data.aws_ami.amazon_linux.id
    name          = data.aws_ami.amazon_linux.name
    description   = data.aws_ami.amazon_linux.description
    creation_date = data.aws_ami.amazon_linux.creation_date
    architecture  = data.aws_ami.amazon_linux.architecture
    owner_id      = data.aws_ami.amazon_linux.owner_id
  }
}

# ===========================================
# NETWORKING OUTPUTS
# ===========================================

output "vpc_info" {
  description = "VPC information"
  value = var.create_vpc ? {
    vpc_id     = aws_vpc.main[0].id
    vpc_cidr   = aws_vpc.main[0].cidr_block
    vpc_arn    = aws_vpc.main[0].arn
    igw_id     = aws_internet_gateway.main[0].id
    custom_vpc = true
  } : {
    vpc_id     = data.aws_vpc.default[0].id
    vpc_cidr   = data.aws_vpc.default[0].cidr_block
    vpc_arn    = data.aws_vpc.default[0].arn
    igw_id     = "default"
    custom_vpc = false
  }
}

output "subnet_info" {
  description = "Information about subnets"
  value = var.create_vpc ? [
    for subnet in aws_subnet.main : {
      id                = subnet.id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      public            = subnet.map_public_ip_on_launch
    }
  ] : [
    for subnet_id in tolist(data.aws_subnets.default[0].ids) : {
      id = subnet_id
    }
  ]
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web.id
}

# ===========================================
# EC2 INSTANCE OUTPUTS
# ===========================================

output "instance_details" {
  description = "Details of EC2 instances"
  value = [
    for instance in aws_instance.web : {
      id                = instance.id
      private_ip        = instance.private_ip
      public_ip         = instance.public_ip
      public_dns        = instance.public_dns
      availability_zone = instance.availability_zone
      instance_type     = instance.instance_type
      state            = instance.instance_state
      name             = lookup(instance.tags, "Name", "unnamed")
      monitoring       = instance.monitoring
    }
  ]
}

output "instance_urls" {
  description = "URLs to access the web servers"
  value = [
    for instance in aws_instance.web : 
    "http://${instance.public_ip}" if instance.public_ip != ""
  ]
}

# ===========================================
# S3 BUCKET OUTPUTS
# ===========================================

output "s3_bucket_info" {
  description = "S3 bucket information"
  value = {
    id                   = aws_s3_bucket.data.id
    arn                  = aws_s3_bucket.data.arn
    bucket_domain_name   = aws_s3_bucket.data.bucket_domain_name
    region              = aws_s3_bucket.data.region
    versioning_enabled  = aws_s3_bucket_versioning.data.versioning_configuration[0].status == "Enabled"
    encryption_enabled  = true
    public_access_blocked = true
  }
}

output "s3_sample_object" {
  description = "Sample object uploaded to S3"
  value = {
    key  = aws_s3_object.sample.key
    etag = aws_s3_object.sample.etag
    size = length(aws_s3_object.sample.content)
  }
}

# ===========================================
# RANDOM RESOURCE OUTPUTS
# ===========================================

output "random_values" {
  description = "Random values generated"
  value = {
    bucket_suffix = random_id.bucket_suffix.hex
    pet_name      = random_pet.server.id
    password_hint = "Password stored in random_password.db (sensitive)"
  }
}

# ===========================================
# ELASTIC IP OUTPUTS (IF CREATED)
# ===========================================

output "elastic_ips" {
  description = "Elastic IP addresses (if created)"
  value = length(aws_eip.web) > 0 ? [
    for eip in aws_eip.web : {
      public_ip    = eip.public_ip
      allocation_id = eip.allocation_id
      instance_id  = eip.instance
    }
  ] : []
}

# ===========================================
# COMPUTED VALUES
# ===========================================

output "computed_values" {
  description = "Computed local values"
  value = {
    name_prefix      = local.name_prefix
    selected_instance_type = local.instance_type
    total_instances  = local.total_instances
    bucket_name      = local.bucket_name
  }
}

# ===========================================
# VARIABLE VALUES (FOR VERIFICATION)
# ===========================================

output "input_variables" {
  description = "Input variable values used"
  value = {
    username         = var.username
    environment      = var.environment
    instance_count   = var.instance_count
    enable_monitoring = var.enable_monitoring
    aws_region       = var.aws_region
    project_name     = var.project_name
    create_vpc       = var.create_vpc
  }
}

# ===========================================
# SUMMARY OUTPUT
# ===========================================

output "lab_summary" {
  description = "Summary of Lab 2 resources"
  value = {
    message = "Lab 2 deployment successful!"
    user    = var.username
    resources_created = {
      instances       = length(aws_instance.web)
      security_groups = 1
      s3_buckets      = 1
      vpcs           = var.create_vpc ? 1 : 0
      subnets        = var.create_vpc ? length(aws_subnet.main) : 0
      elastic_ips    = length(aws_eip.web)
    }
    total_resources = (
      length(aws_instance.web) + 
      1 + # security group
      1 + # s3 bucket
      (var.create_vpc ? 1 + length(aws_subnet.main) : 0) +
      length(aws_eip.web)
    )
    access_urls = [
      for instance in aws_instance.web : 
      "http://${instance.public_ip}" if instance.public_ip != ""
    ]
    next_steps = [
      "1. Access the web servers using the URLs above",
      "2. Review the S3 bucket contents",
      "3. Examine the outputs with: terraform output -json",
      "4. Try modifying variables and re-applying",
      "5. Clean up with: terraform destroy"
    ]
  }
}

# ===========================================
# SENSITIVE OUTPUT (Example)
# ===========================================

output "database_password" {
  description = "Generated database password (sensitive)"
  value       = random_password.db.result
  sensitive   = true
}