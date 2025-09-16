#!/bin/bash
yum update -y
yum install -y httpd php mysql

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create dynamic web page
cat <<EOF > /var/www/html/index.php
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Tier Application - Server ${server_id}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f4f4f4; }
        .container { background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 20px; }
        .info-section { background-color: #ecf0f1; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .server-id { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Multi-Tier VPC Application</h1>
            <h2>Server <span class="server-id">${server_id}</span> - Owner: ${username}</h2>
        </div>

        <div class="info-section">
            <h3>Infrastructure Details</h3>
            <p><strong>Environment:</strong> ${environment}</p>
            <p><strong>Instance ID:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
            <p><strong>Availability Zone:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/placement/availability-zone'); ?></p>
            <p><strong>Private IP:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4'); ?></p>
            <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?></p>
        </div>

        <div class="info-section">
            <h3>VPC Architecture Features</h3>
            <ul>
                <li>✅ Multi-AZ deployment for high availability</li>
                <li>✅ Private subnets for application tier security</li>
                <li>✅ NAT Gateways for secure outbound internet access</li>
                <li>✅ Application Load Balancer with health checks</li>
                <li>✅ Layered security groups for network segmentation</li>
                <li>✅ Dedicated database subnets (no internet access)</li>
                <li>✅ Bastion host for secure administrative access</li>
            </ul>
        </div>

        <div class="info-section">
            <h3>Network Configuration</h3>
            <p><strong>VPC CIDR:</strong> 10.0.0.0/16</p>
            <p><strong>Subnet Type:</strong> Private Application Subnet</p>
            <p><strong>Route Table:</strong> Routes through NAT Gateway</p>
            <p><strong>Security Group:</strong> Allows HTTP from ALB, SSH from Bastion</p>
        </div>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown apache:apache /var/www/html/index.php
chmod 644 /var/www/html/index.php

# Restart Apache to ensure everything is loaded
systemctl restart httpd

# Create health check endpoint
echo "OK" > /var/www/html/health.html