# main.tf - Advanced Variable Patterns Infrastructure

# Security Group with dynamic ingress rules
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web servers"
  vpc_id      = data.aws_vpc.default.id

  # Dynamic ingress rules from local configuration
  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
    Type = "WebServer"
  })
}

# EC2 Instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.current_config.instance_type
  subnet_id     = data.aws_subnets.default.ids[0]
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  vpc_security_group_ids = [aws_security_group.web.id]

  monitoring = local.current_config.monitoring

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = local.current_config.volume_size
    volume_type           = "gp3"
    encrypted             = var.security_config.enable_encryption
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>${var.application_config.name} v${var.application_config.version}</h1>" > /var/www/html/index.html
    echo "<p>Environment: ${var.environment}</p>" >> /var/www/html/index.html
    echo "<p>Owner: ${var.username}</p>" >> /var/www/html/index.html
    echo '{"status":"healthy"}' > /var/www/html/health
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
    Type = "WebServer"
  })
}
