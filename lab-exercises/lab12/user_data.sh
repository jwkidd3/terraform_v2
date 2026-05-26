#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

cat <<HTML > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head><title>GitOps Demo - ${username}</title></head>
<body style="font-family: sans-serif; padding: 40px;">
  <h1>GitOps Deployment Demo</h1>
  <p><strong>Owner:</strong> ${username}</p>
  <p><strong>Environment:</strong> ${environment}</p>
  <p><strong>App Version:</strong> ${app_version}</p>
  <p>This instance was deployed by Terraform Cloud via a Git push.</p>
</body>
</html>
HTML

systemctl restart httpd
