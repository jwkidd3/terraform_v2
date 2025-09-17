#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1  # Log all output

echo "Starting user data script at $(date)"

# Update system
echo "Updating system packages..."
yum update -y

# Install Apache HTTP Server and PHP
echo "Installing Apache and PHP..."
yum install -y httpd php

echo "Apache installation completed"

# Create web directory if it doesn't exist
mkdir -p /var/www/html

# Start and enable Apache
echo "Starting Apache..."
systemctl start httpd
systemctl enable httpd

# Wait for service to be ready
sleep 3

# Verify Apache is running
if systemctl is-active --quiet httpd; then
    echo "Apache started successfully"
else
    echo "Apache failed to start with systemctl, trying manual start..."
    # Try to start manually
    /usr/sbin/httpd -D FOREGROUND &
    sleep 3
fi

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
                <li>✅ Simple 2-tier architecture (web and data layers)</li>
                <li>✅ Private subnets for enhanced security</li>
            </ul>
        </div>

        <div class="info-section">
            <h3>Network Configuration</h3>
            <p><strong>VPC CIDR:</strong> 10.0.0.0/16</p>
            <p><strong>Subnet Type:</strong> Private Application Subnet</p>
            <p><strong>Route Table:</strong> Routes through single NAT Gateway (cost optimized)</p>
            <p><strong>Security Group:</strong> Allows HTTP from ALB only</p>
        </div>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown apache:apache /var/www/html/index.php 2>/dev/null || chown www-data:www-data /var/www/html/index.php 2>/dev/null || true
chmod 644 /var/www/html/index.php

# Restart Apache to ensure everything is loaded
echo "Restarting Apache to load new configuration..."
if systemctl restart httpd; then
    echo "Apache restarted successfully"
else
    echo "systemctl restart failed, trying manual restart..."
    pkill -f httpd 2>/dev/null || true
    sleep 2
    /usr/sbin/httpd -D FOREGROUND &
    sleep 2
fi

# Create health check endpoint
echo "OK" > /var/www/html/health.html
chown apache:apache /var/www/html/health.html 2>/dev/null || chown www-data:www-data /var/www/html/health.html 2>/dev/null || true

# Create backup static HTML index page (fallback if PHP fails)
cat <<EOF > /var/www/html/index.html
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
        .status { color: #27ae60; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Multi-Tier VPC Application</h1>
            <h2>Server <span class="server-id">${server_id}</span> - Owner: ${username}</h2>
            <p class="status">✅ Apache HTTP Server Running</p>
        </div>

        <div class="info-section">
            <h3>Infrastructure Details</h3>
            <p><strong>Environment:</strong> ${environment}</p>
            <p><strong>Server:</strong> Web Server ${server_id}</p>
            <p><strong>VPC CIDR:</strong> 10.0.0.0/16</p>
            <p><strong>Subnet Type:</strong> Private Application Subnet</p>
        </div>

        <div class="info-section">
            <h3>VPC Architecture Features</h3>
            <ul>
                <li>✅ Multi-AZ deployment for high availability</li>
                <li>✅ Private subnets for application tier security</li>
                <li>✅ NAT Gateways for secure outbound internet access</li>
                <li>✅ Application Load Balancer with health checks</li>
                <li>✅ Layered security groups for network segmentation</li>
                <li>✅ Simple 2-tier architecture (web and data layers)</li>
                <li>✅ Private subnets for enhanced security</li>
            </ul>
        </div>

        <div class="info-section">
            <h3>Health Check Status</h3>
            <p class="status">✅ Health check endpoint: /health.html</p>
            <p class="status">✅ Web server responding on port 80</p>
            <p><strong>Last updated:</strong> <script>document.write(new Date().toLocaleString());</script></p>
        </div>
    </div>
</body>
</html>
EOF

chown apache:apache /var/www/html/index.html 2>/dev/null || chown www-data:www-data /var/www/html/index.html 2>/dev/null || true

# Test health check endpoint
echo "Testing health check endpoint..."
sleep 5
if curl -s localhost/health.html | grep -q "OK"; then
    echo "✅ Health check endpoint responding correctly"
else
    echo "⚠️  Health check endpoint not responding, creating again..."
    echo "OK" > /var/www/html/health.html
    chown apache:apache /var/www/html/health.html 2>/dev/null || true
fi

# Test main web page
if curl -s localhost/ | grep -q "Multi-Tier"; then
    echo "✅ Main web page responding correctly"
else
    echo "⚠️  Main web page not responding as expected"
fi

# Final status check
echo "Performing final status check..."
if pgrep httpd > /dev/null; then
    echo "SUCCESS: Apache is running (PID: $(pgrep httpd | head -1))"
    echo "Web server listening on port 80"
    netstat -tlnp | grep :80 || ss -tlnp | grep :80 || echo "Port 80 status check failed"

    # Test both endpoints
    echo "Available endpoints:"
    echo "  - http://[ALB-DNS]/ (main application)"
    echo "  - http://[ALB-DNS]/health.html (health check)"
else
    echo "WARNING: Apache does not appear to be running"
    echo "Attempting one final restart..."
    systemctl start httpd || /usr/sbin/httpd &
    sleep 3
fi

# Log completion
echo "Web server setup completed at $(date)"
echo "Health check endpoint: /health.html"
echo "Main application endpoint: /"
echo "Check /var/log/user-data.log for detailed logs"