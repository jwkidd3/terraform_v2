#!/bin/bash
yum update -y
yum install -y httpd

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Look up the instance ID from the instance metadata service.
# Amazon Linux 2023 requires IMDSv2, so first request a session token.
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Create a dynamic web page
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>${app_name} - ${environment}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #232f3e; color: white; padding: 20px; }
        .content { padding: 20px; }
        .info-box { background-color: #f0f0f0; padding: 15px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Welcome to ${app_name}!</h1>
        <h2>Environment: ${environment}</h2>
    </div>
    <div class="content">
        <div class="info-box">
            <h3>Application Details</h3>
            <p><strong>Owner:</strong> ${username}</p>
            <p><strong>Server launched:</strong> $(date)</p>
            <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
        </div>
        <div class="info-box">
            <h3>Module Features Demonstrated</h3>
            <ul>
                <li>Variable validation and defaults</li>
                <li>Local values and consistent naming</li>
                <li>Data sources for dynamic resource selection</li>
                <li>CloudWatch monitoring with conditional creation</li>
                <li>Template files for dynamic content</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
