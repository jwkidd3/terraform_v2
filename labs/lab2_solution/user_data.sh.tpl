#!/bin/bash
# Lab 2: Variables and Data Sources - User Data Script Template
# This script runs when the EC2 instance starts up

# ===========================================
# LOG SETUP
# ===========================================
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== Lab 2 User Data Script Starting ==="
echo "Instance: ${instance_name}"
echo "Environment: ${environment}"
echo "Username: ${username}"
echo "Pet Name: ${pet_name}"
echo "Timestamp: $(date)"

# ===========================================
# SYSTEM UPDATES
# ===========================================
echo "=== Updating system packages ==="
yum update -y

# ===========================================
# INSTALL SOFTWARE
# ===========================================
echo "=== Installing software packages ==="

# Install Apache web server
yum install -y httpd

# Install useful utilities
yum install -y \
    git \
    htop \
    tree \
    jq \
    curl \
    wget \
    unzip

# ===========================================
# CONFIGURE WEB SERVER
# ===========================================
echo "=== Configuring web server ==="

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create a comprehensive web page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lab 2: ${instance_name}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .info-card {
            background: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #3498db;
        }
        .info-card h3 {
            margin-top: 0;
            color: #2c3e50;
        }
        .highlight {
            background: #e8f6f3;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        .status {
            background: #d5edda;
            color: #155724;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #7f8c8d;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Terraform Lab 2: Variables and Data Sources</h1>
        
        <div class="status">
            <strong>✅ Instance Successfully Deployed!</strong> 
            This page was generated dynamically using Terraform variables and templates.
        </div>

        <div class="info-grid">
            <div class="info-card">
                <h3>🏷️ Instance Information</h3>
                <p><strong>Name:</strong> ${instance_name}</p>
                <p><strong>Pet Name:</strong> ${pet_name}</p>
                <p><strong>Environment:</strong> ${environment}</p>
                <p><strong>Owner:</strong> ${username}</p>
            </div>

            <div class="info-card">
                <h3>🖥️ System Information</h3>
                <p><strong>Hostname:</strong> <span id="hostname">Loading...</span></p>
                <p><strong>Instance ID:</strong> <span id="instance-id">Loading...</span></p>
                <p><strong>Instance Type:</strong> <span id="instance-type">Loading...</span></p>
                <p><strong>Region:</strong> <span id="region">Loading...</span></p>
            </div>

            <div class="info-card">
                <h3>🌐 Network Information</h3>
                <p><strong>Local IP:</strong> <span id="local-ip">Loading...</span></p>
                <p><strong>Public IP:</strong> <span id="public-ip">Loading...</span></p>
                <p><strong>Availability Zone:</strong> <span id="az">Loading...</span></p>
            </div>

            <div class="info-card">
                <h3>⏰ Deployment Information</h3>
                <p><strong>Boot Time:</strong> <span id="boot-time">Loading...</span></p>
                <p><strong>Uptime:</strong> <span id="uptime">Loading...</span></p>
                <p><strong>Last Update:</strong> <span id="last-update">Loading...</span></p>
            </div>
        </div>

        <h2>📊 Lab 2 Learning Objectives</h2>
        <table>
            <tr>
                <th>Concept</th>
                <th>Implementation</th>
                <th>Status</th>
            </tr>
            <tr>
                <td>Variable Types</td>
                <td>String, Number, Boolean, List, Map, Object</td>
                <td>✅ Demonstrated</td>
            </tr>
            <tr>
                <td>Variable Validation</td>
                <td>Input constraints and error messages</td>
                <td>✅ Implemented</td>
            </tr>
            <tr>
                <td>Data Sources</td>
                <td>AMI lookup, Account info, AZ discovery</td>
                <td>✅ Active</td>
            </tr>
            <tr>
                <td>Local Values</td>
                <td>Computed values and expressions</td>
                <td>✅ Used</td>
            </tr>
            <tr>
                <td>Template Files</td>
                <td>This page generated from template</td>
                <td>✅ Rendered</td>
            </tr>
            <tr>
                <td>Resource Tagging</td>
                <td>Comprehensive tagging strategy</td>
                <td>✅ Applied</td>
            </tr>
        </table>

        <div class="highlight">
            <h3>🎯 Next Steps</h3>
            <ol>
                <li>Examine the Terraform outputs: <code>terraform output</code></li>
                <li>Try changing variables and re-applying: <code>terraform apply</code></li>
                <li>View the generated JSON data in S3</li>
                <li>Explore the AWS console to see all created resources</li>
                <li>Test different variable combinations</li>
            </ol>
        </div>

        <div class="footer">
            <p>🏗️ Built with Terraform | 📚 Lab 2: Variables and Data Sources</p>
            <p>User: <strong>${username}</strong> | Environment: <strong>${environment}</strong></p>
        </div>
    </div>

    <script>
        // Fetch AWS instance metadata
        async function fetchMetadata() {
            try {
                // Get instance metadata
                const responses = await Promise.allSettled([
                    fetch('http://169.254.169.254/latest/meta-data/hostname'),
                    fetch('http://169.254.169.254/latest/meta-data/instance-id'),
                    fetch('http://169.254.169.254/latest/meta-data/instance-type'),
                    fetch('http://169.254.169.254/latest/meta-data/placement/region'),
                    fetch('http://169.254.169.254/latest/meta-data/local-ipv4'),
                    fetch('http://169.254.169.254/latest/meta-data/public-ipv4'),
                    fetch('http://169.254.169.254/latest/meta-data/placement/availability-zone')
                ]);

                const [hostname, instanceId, instanceType, region, localIp, publicIp, az] = 
                    await Promise.all(responses.map(async (r) => 
                        r.status === 'fulfilled' && r.value.ok ? r.value.text() : 'N/A'
                    ));

                // Update DOM elements
                document.getElementById('hostname').textContent = hostname;
                document.getElementById('instance-id').textContent = instanceId;
                document.getElementById('instance-type').textContent = instanceType;
                document.getElementById('region').textContent = region;
                document.getElementById('local-ip').textContent = localIp;
                document.getElementById('public-ip').textContent = publicIp;
                document.getElementById('az').textContent = az;
                
            } catch (error) {
                console.log('Metadata fetch failed (normal in some environments):', error);
                document.getElementById('hostname').textContent = 'Metadata unavailable';
            }
        }

        // Update dynamic content
        function updateDynamicContent() {
            document.getElementById('boot-time').textContent = new Date().toISOString();
            document.getElementById('last-update').textContent = new Date().toLocaleString();
        }

        // Fetch uptime
        function updateUptime() {
            fetch('/cgi-bin/uptime')
                .then(response => response.text())
                .then(data => {
                    document.getElementById('uptime').textContent = data.trim() || 'Available after boot';
                })
                .catch(() => {
                    document.getElementById('uptime').textContent = 'System starting...';
                });
        }

        // Initialize page
        document.addEventListener('DOMContentLoaded', function() {
            fetchMetadata();
            updateDynamicContent();
            updateUptime();
            
            // Update uptime every 30 seconds
            setInterval(updateUptime, 30000);
        });
    </script>
</body>
</html>
EOF

# ===========================================
# CREATE SIMPLE CGI SCRIPT FOR UPTIME
# ===========================================
echo "=== Setting up CGI for uptime ==="

# Enable CGI module
echo "LoadModule cgi_module modules/mod_cgi.so" >> /etc/httpd/conf/httpd.conf

# Create cgi-bin directory
mkdir -p /var/www/cgi-bin
chmod 755 /var/www/cgi-bin

# Create uptime script
cat > /var/www/cgi-bin/uptime << 'EOF'
#!/bin/bash
echo "Content-Type: text/plain"
echo ""
uptime | sed 's/.*up //' | sed 's/,.*//'
EOF

chmod +x /var/www/cgi-bin/uptime

# Configure Apache for CGI
cat >> /etc/httpd/conf/httpd.conf << 'EOF'

# Enable CGI scripts
ScriptAlias /cgi-bin/ /var/www/cgi-bin/
<Directory "/var/www/cgi-bin">
    AllowOverride None
    Options +ExecCGI
    Require all granted
</Directory>
EOF

# ===========================================
# CREATE SYSTEM INFORMATION FILES
# ===========================================
echo "=== Creating system information ==="

# Create system info directory
mkdir -p /var/www/html/info

# Create a JSON endpoint with system information
cat > /var/www/html/info/system.json << EOF
{
    "lab": "2",
    "instance_name": "${instance_name}",
    "environment": "${environment}",
    "username": "${username}",
    "pet_name": "${pet_name}",
    "deployment_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "terraform_managed": true,
    "aws_region": "us-east-2",
    "lab_objectives": {
        "variables": "Demonstrated multiple variable types",
        "validation": "Implemented input validation rules",
        "data_sources": "Used AWS AMI and account data sources",
        "locals": "Computed values with local expressions",
        "outputs": "Comprehensive output definitions",
        "templates": "Generated this page from template"
    }
}
EOF

# ===========================================
# RESTART SERVICES
# ===========================================
echo "=== Restarting services ==="
systemctl restart httpd

# ===========================================
# FINAL STATUS
# ===========================================
echo "=== User Data Script Completed Successfully ==="
echo "Web server is running on port 80"
echo "Instance: ${instance_name}"
echo "Environment: ${environment}"
echo "Username: ${username}"
echo "Pet Name: ${pet_name}"
echo "Access URL: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "System info: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/info/system.json"
echo "=== Script finished at $(date) ==="