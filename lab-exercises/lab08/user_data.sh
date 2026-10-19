#!/bin/bash
yum update -y
yum install -y httpd

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Amazon Linux 2023 requires IMDSv2: fetch a session token first, then pass it
# on every instance metadata request
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

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
            <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
            <p><strong>Availability Zone:</strong> $AZ</p>
            <p><strong>Server Time:</strong> $(date)</p>
        </div>
    </div>
</body>
</html>
EOF