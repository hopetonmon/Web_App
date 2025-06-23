#!/bin/bash
set -e

# Install nginx
sudo apt update
sudo apt install -y nginx
echo "<h1>Hello from My (SCALED) Terraform Web Server!</h1><p>This is a Scaled Website running on an EC2 instance with user_data.</p>" | sudo tee /var/www/html/index.html
sudo systemctl start nginx
sudo systemctl enable nginx

# Install CloudWatch Agent
sudo apt install -y amazon-cloudwatch-agent

# Create basic config (you can expand this later)
cat <<EOF | sudo tee /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "metrics": {
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["*"]
      }
    }
  }
}
EOF

# Start the agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
