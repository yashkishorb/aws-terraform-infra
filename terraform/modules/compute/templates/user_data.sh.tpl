#!/bin/bash
# Minimal bootstrap: install a web server and serve a simple health/identity
# page so the ALB has something real to health-check and the ASG's
# rolling behavior is easy to demo (each instance shows its own instance ID).
set -euo pipefail

dnf install -y httpd

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")" http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /var/www/html/index.html <<EOF
<html>
  <head><title>${project_name} - ${environment}</title></head>
  <body style="font-family: sans-serif; text-align: center; margin-top: 10%;">
    <h1>${project_name} (${environment})</h1>
    <p>Served by instance: $INSTANCE_ID</p>
    <p>Availability Zone: $AZ</p>
  </body>
</html>
EOF

cat > /var/www/html/health <<EOF
OK
EOF

systemctl enable httpd
systemctl start httpd
