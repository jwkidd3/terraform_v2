#!/bin/bash
yum update -y
yum install -y httpd

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create environment-specific content
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>${environment} Environment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #232f3e; color: white; padding: 20px; }
        .content { padding: 20px; }
        .env-${environment} { border-left: 5px solid #ff9900; padding-left: 15px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Multi-Environment Demo</h1>
        <h2>Environment: ${environment}</h2>
    </div>
    <div class="content">
        <div class="env-${environment}">
            <h3>Server Information</h3>
            <p><strong>Owner:</strong> ${username}</p>
            <p><strong>Environment:</strong> ${environment}</p>
            <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
            <p><strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
            <p><strong>Server Time:</strong> $(date)</p>
        </div>
    </div>
</body>
</html>
EOF