output "vpc_info" {
  description = "VPC information from registry module"
  value = {
    vpc_id             = module.vpc.vpc_id
    vpc_cidr_block     = module.vpc.vpc_cidr_block
    private_subnet_ids = module.vpc.private_subnets
    public_subnet_ids  = module.vpc.public_subnets
    nat_gateway_ids    = module.vpc.natgw_ids
    internet_gateway_id = module.vpc.igw_id
  }
}

output "security_groups" {
  description = "Security group information from registry modules"
  value = {
    web_security_group_id = module.web_security_group.security_group_id
    ssh_security_group_id = module.ssh_security_group.security_group_id
  }
}

output "application_endpoint" {
  description = "Application load balancer DNS name"
  value = "http://${aws_lb.main.dns_name}"
}

output "web_servers" {
  description = "Web server instances"
  value = {
    for i, instance in aws_instance.web : "web-${i + 1}" => {
      id         = instance.id
      private_ip = instance.private_ip
      subnet_id  = instance.subnet_id
    }
  }
}

output "s3_bucket" {
  description = "S3 bucket information from registry module"
  value = {
    bucket_id                 = module.s3_logs.s3_bucket_id
    bucket_arn               = module.s3_logs.s3_bucket_arn
    bucket_domain_name       = module.s3_logs.s3_bucket_bucket_domain_name
    bucket_regional_domain_name = module.s3_logs.s3_bucket_bucket_regional_domain_name
  }
}