output "vpc_info" {
  description = "VPC configuration details"
  value = {
    vpc_id             = aws_vpc.main.id
    vpc_cidr           = aws_vpc.main.cidr_block
    availability_zones = local.availability_zones
    public_subnet_ids  = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id
  }
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "URL to access the web application"
  value       = "http://${aws_lb.main.dns_name}"
}


output "web_server_private_ips" {
  description = "Private IP addresses of web servers"
  value       = aws_instance.web[*].private_ip
}

output "security_groups" {
  description = "Security group IDs for different tiers"
  value = {
    alb_security_group = aws_security_group.alb.id
    web_security_group = aws_security_group.web.id
  }
}

output "nat_gateway_ip" {
  description = "Public IP address of NAT Gateway"
  value       = aws_eip.nat.public_ip
}