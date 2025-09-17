#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting GitOps demo web server setup..."

# Update system
yum update -y

# Install Apache and git
yum install -y httpd git

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create health check endpoint
echo "OK" > /var/www/html/health

# Create main application page
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>GitOps Lab 12 - ${username}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .header {
            text-align: center;
            border-bottom: 2px solid rgba(255,255,255,0.3);
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .info-card {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #4fc3f7;
        }
        .version {
            background: #4fc3f7;
            color: #000;
            padding: 5px 15px;
            border-radius: 20px;
            display: inline-block;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 GitOps Deployment Lab 12</h1>
            <h2>Owner: ${username} | Environment: ${environment}</h2>
            <div class="version">App Version: ${app_version}</div>
        </div>

        <div class="info-grid">
            <div class="info-card">
                <h3>🔄 GitOps Workflow</h3>
                <p><strong>Repository:</strong> terraform-lab12</p>
                <p><strong>Branch:</strong> main</p>
                <p><strong>Trigger:</strong> Git push</p>
                <p><strong>Execution:</strong> Terraform Cloud</p>
                <p><strong>Status:</strong> ✅ Deployed via GitHub</p>
            </div>

            <div class="info-card">
                <h3>🏗️ Infrastructure</h3>
                <p><strong>VPC:</strong> Custom with public/private subnets</p>
                <p><strong>Load Balancer:</strong> Application Load Balancer</p>
                <p><strong>Auto Scaling:</strong> 1-3 instances</p>
                <p><strong>Storage:</strong> S3 for static assets</p>
            </div>

            <div class="info-card">
                <h3>☁️ Terraform Cloud</h3>
                <p><strong>Workspace:</strong> VCS-driven</p>
                <p><strong>State:</strong> Remotely managed</p>
                <p><strong>Runs:</strong> Automatic on Git push</p>
                <p><strong>Collaboration:</strong> Team-enabled</p>
            </div>

            <div class="info-card">
                <h3>📊 Deployment Info</h3>
                <p><strong>Instance ID:</strong> <span id="instance-id">Loading...</span></p>
                <p><strong>Availability Zone:</strong> <span id="az">Loading...</span></p>
                <p><strong>Deployed:</strong> $(date)</p>
                <p><strong>Health Check:</strong> <a href="/health" target="_blank">/health</a></p>
            </div>
        </div>

        <div style="text-align: center; margin-top: 30px; padding: 20px; background: rgba(76, 175, 80, 0.2); border-radius: 8px;">
            <h3>🎉 Successfully Deployed via GitOps!</h3>
            <p>This infrastructure was deployed automatically when code was pushed to GitHub,
            demonstrating a complete GitOps workflow with Terraform Cloud.</p>
        </div>
    </div>

    <script>
        // Fetch instance metadata
        fetch('http://169.254.169.254/latest/meta-data/instance-id')
            .then(response => response.text())
            .then(data => document.getElementById('instance-id').textContent = data)
            .catch(() => document.getElementById('instance-id').textContent = 'Not available');

        fetch('http://169.254.169.254/latest/meta-data/placement/availability-zone')
            .then(response => response.text())
            .then(data => document.getElementById('az').textContent = data)
            .catch(() => document.getElementById('az').textContent = 'Not available');
    </script>
</body>
</html>
EOF

# Set permissions
chown apache:apache /var/www/html/index.html /var/www/html/health
chmod 644 /var/www/html/index.html /var/www/html/health

# Restart Apache
systemctl restart httpd

echo "GitOps web server setup completed successfully"
echo "Instance is ready for GitOps workflow demonstration"