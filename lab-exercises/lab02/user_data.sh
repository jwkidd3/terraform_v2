#!/bin/bash
# user_data.sh - EC2 instance bootstrap script

# Variables from Terraform template
BUCKET_NAME="${bucket_name}"
STUDENT_ID="${student_id}"
ENVIRONMENT="${environment}"
PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"

# Update system packages
yum update -y

# Install required packages
yum install -y httpd aws-cli jq

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Start and enable services
systemctl start httpd
systemctl enable httpd

# Create web content
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terraform Lab 2 - AWS Infrastructure</title>
    <style>
        body { 
            font-family: 'Arial', sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            background: rgba(255,255,255,0.1); 
            padding: 30px; 
            border-radius: 15px; 
            backdrop-filter: blur(10px);
        }
        .header { text-align: center; margin-bottom: 30px; }
        .info-card { 
            background: rgba(255,255,255,0.2); 
            padding: 20px; 
            margin: 15px 0; 
            border-radius: 10px; 
        }
        .terraform { color: #623CE4; font-weight: bold; text-shadow: 1px 1px 2px rgba(0,0,0,0.5); }
        .success { color: #4CAF50; }
        .aws-orange { color: #FF9900; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        @media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 <span class="terraform">Terraform</span> Lab 2 Success!</h1>
            <h2>AWS Infrastructure Deployment</h2>
        </div>
        
        <div class="grid">
            <div class="info-card">
                <h3>📊 Infrastructure Details</h3>
                <p><strong>Student ID:</strong> $STUDENT_ID</p>
                <p><strong>Environment:</strong> $ENVIRONMENT</p>
                <p><strong>Project:</strong> $PROJECT_NAME</p>
                <p><strong>Region:</strong> $AWS_REGION</p>
            </div>
            
            <div class="info-card">
                <h3>🏗️ Resources Created</h3>
                <ul>
                    <li>EC2 Instance (this server!)</li>
                    <li>S3 Bucket: $BUCKET_NAME</li>
                    <li>Security Groups</li>
                    <li>IAM Roles & Policies</li>
                </ul>
            </div>
        </div>
        
        <div class="info-card">
            <h3>✅ What You've Accomplished</h3>
            <ul>
                <li><span class="success">✓</span> Deployed production-ready AWS infrastructure</li>
                <li><span class="success">✓</span> Implemented security best practices</li>
                <li><span class="success">✓</span> Used enterprise tagging strategies</li>
                <li><span class="success">✓</span> Applied proper IAM permissions</li>
                <li><span class="success">✓</span> Configured encrypted storage</li>
            </ul>
        </div>
        
        <div class="info-card">
            <h3>🎯 <span class="aws-orange">AWS</span> + <span class="terraform">Terraform</span> = Infrastructure as Code</h3>
            <p>This entire environment was created from code - no manual clicking required!</p>
            <p><strong>Next:</strong> You'll learn advanced variables and data source patterns.</p>
        </div>
    </div>
</body>
</html>
EOF

# Test S3 connectivity and create a test file
echo "Infrastructure deployed successfully on $(date)" > /tmp/deployment-status.txt
aws s3 cp /tmp/deployment-status.txt s3://$BUCKET_NAME/status/deployment-status.txt --region $AWS_REGION

# Configure log forwarding to CloudWatch (optional)
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "/aws/ec2/terraform-lab2/httpd/access",
                        "log_stream_name": "$STUDENT_ID-{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF