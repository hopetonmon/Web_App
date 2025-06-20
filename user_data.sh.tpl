#!/bin/bash
set -e

# Generate 3-character code and set hostname
code=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
hostnamectl set-hostname instance-$code

# Install nginx
sudo apt update
sudo apt install -y nginx
echo "<h1>Hello from My (SCALED) Terraform Web Server!</h1><p>This is a Scaled Website running on an EC2 instance with user_data.</p>" | sudo tee /var/www/html/index.html
sudo systemctl start nginx
sudo systemctl enable nginx

# Install New Relic Infrastructure Agent
curl -Ls https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/newrelic-infra-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/newrelic-infra-archive-keyring.gpg] https://download.newrelic.com/infrastructure_agent/linux/apt focal main" | sudo tee /etc/apt/sources.list.d/newrelic-infra.list
sudo apt update
sudo apt install -y newrelic-infra

# Configure New Relic with injected license key
echo "license_key: ${new_relic_license_key}" | sudo tee -a /etc/newrelic-infra.yml

# Start and enable agent
sudo systemctl enable newrelic-infra
sudo systemctl start newrelic-infra
