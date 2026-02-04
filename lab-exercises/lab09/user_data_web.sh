#!/bin/bash
# Simplified user data script for faster startup

# Create health check endpoint FIRST (before any package operations)
mkdir -p /var/www/html
echo "OK" > /var/www/html/health.html

# Install and start Apache (skip yum update for faster startup)
yum install -y httpd

# Start Apache immediately
systemctl start httpd
systemctl enable httpd

# Create simple HTML page
cat <<'HTMLEOF' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Web Server ${server_id}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; max-width: 600px; margin: auto; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 15px; }
        .info { background: #ecf0f1; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .server { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>2-Tier VPC Application</h1>
        <p>Server <span class="server">${server_id}</span> | Owner: ${username}</p>

        <div class="info">
            <h3>Server Details</h3>
            <p><strong>Environment:</strong> ${environment}</p>
            <p><strong>Server ID:</strong> ${server_id}</p>
            <p><strong>Subnet:</strong> Private Application Subnet</p>
        </div>

        <div class="info">
            <h3>Architecture</h3>
            <ul>
                <li>Multi-AZ deployment</li>
                <li>Private subnets for web servers</li>
                <li>NAT Gateway for outbound access</li>
                <li>ALB with health checks</li>
            </ul>
        </div>
    </div>
</body>
</html>
HTMLEOF

# Set permissions
chmod 644 /var/www/html/index.html
chmod 644 /var/www/html/health.html
