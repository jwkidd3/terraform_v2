#!/bin/bash
# user_data.sh - Advanced Instance Initialization Script

# Variables from template
APP_NAME="${app_name}"
APP_VERSION="${app_version}"
APP_PORT="${app_port}"
ENVIRONMENT="${environment}"
USERNAME="${username}"

# Update system
yum update -y

# Install packages
yum install -y \
    httpd \
    mysql \
    wget \
    curl \
    git \
    htop \
    awslogs

# Configure Apache
systemctl start httpd
systemctl enable httpd

# Create application directory
mkdir -p /var/www/html/app

# Create enhanced web application
cat << EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$APP_NAME - $ENVIRONMENT</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .info { background: #e7f3ff; padding: 10px; border-radius: 4px; margin: 10px 0; }
        .success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .warning { background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$APP_NAME</h1>
        <div class="info success">
            <strong>Application Status:</strong> Running Successfully
        </div>
        <div class="info">
            <strong>Version:</strong> $APP_VERSION<br>
            <strong>Environment:</strong> $ENVIRONMENT<br>
            <strong>Username:</strong> $USERNAME<br>
            <strong>Port:</strong> $APP_PORT<br>
            <strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)<br>
            <strong>Instance Type:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-type)<br>
            <strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)<br>
            <strong>Private IP:</strong> $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)<br>
            <strong>Public IP:</strong> $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
        </div>
        <div class="info warning">
            <strong>Note:</strong> This is a Terraform training environment
        </div>
    </div>
</body>
</html>
EOF

# Create health check endpoint
cat << EOF > /var/www/html/health
{
    "status": "healthy",
    "application": "$APP_NAME",
    "version": "$APP_VERSION",
    "environment": "$ENVIRONMENT",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Configure application port (if not 80)
if [ "$APP_PORT" != "80" ]; then
    echo "Listen $APP_PORT" >> /etc/httpd/conf/httpd.conf
    cat << EOF >> /etc/httpd/conf/httpd.conf

<VirtualHost *:$APP_PORT>
    DocumentRoot /var/www/html
    ServerName localhost
</VirtualHost>
EOF
    systemctl restart httpd
fi

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat << EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "metrics": {
        "namespace": "$APP_NAME",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "$APP_NAME/httpd/access",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "$APP_NAME/httpd/error",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Create application startup script
cat << EOF > /etc/systemd/system/app-monitor.service
[Unit]
Description=Application Health Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/watch -n 30 'curl -f http://localhost/health || systemctl restart httpd'
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app-monitor
systemctl start app-monitor

# Final status check
systemctl status httpd
systemctl status amazon-cloudwatch-agent
systemctl status app-monitor

echo "Instance initialization completed successfully!" >> /var/log/user-data.log