#!/bin/bash
# This script installs Jenkins LTS and configures Nginx as a reverse proxy.

# Install necessary packages for Jenkins
echo "Updating apt package list..."
sudo apt-get update
echo "Installing OpenJDK 17, ca-certificates, curl, and gnupg..."
sudo apt-get install -y openjdk-17-jdk # Jenkins requires Java 11 or 17
sudo apt-get install -y ca-certificates curl gnupg

# Add Jenkins GPG key
echo "Adding Jenkins GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins APT repository
echo "Adding Jenkins APT repository..."
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  "https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update apt cache and install Jenkins
echo "Updating apt cache and installing Jenkins..."
sudo apt-get update
sudo apt-get install -y jenkins

# Reload systemd daemon to recognize new Jenkins service unit file
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
# Give systemd a moment to process (optional, but can help with timing)
sleep 5

# Start and enable Jenkins service
echo "Starting and enabling Jenkins service..."
sudo systemctl start jenkins
sudo systemctl enable jenkins

# --- START: Install and Configure Nginx as a Reverse Proxy ---
echo "Installing Nginx..."
sudo apt-get install -y nginx

echo "Configuring Nginx for Jenkins reverse proxy..."
# Create Nginx configuration for Jenkins
# Using <<'EOF' to prevent shell variable expansion inside the heredoc
# Terraform will replace ${var.domain_name} before the script runs on the VM.
sudo tee /etc/nginx/sites-available/jenkins <<'EOF'
server {
    listen 80;
    server_name ${var.domain_name}; # This will be replaced by Terraform

    location / {
        proxy_pass http://127.0.0.1:8080; # Jenkins default port
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 150;
        proxy_send_timeout 100;
        proxy_read_timeout 100;
        proxy_buffers 16 64k;
        proxy_buffer_size 128k;
    }
}
EOF

# Enable the Nginx site and remove default
echo "Enabling Nginx site and removing default..."
sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t && echo "Nginx config test passed." || echo "Nginx config test failed!"

# Restart Nginx service
echo "Restarting and enabling Nginx service..."
sudo systemctl restart nginx
sudo systemctl enable nginx
echo "Nginx configured and started as reverse proxy for Jenkins."
# --- END: Install and Configure Nginx as a Reverse Proxy ---

# --- START: Configure Jenkins URL ---
# Wait for Jenkins to be fully up and running before attempting configuration
echo "Waiting for Jenkins to be fully available on port 8080..."
until curl -s http://127.0.0.1:8080/login > /dev/null; do
  sleep 5
done
echo "Jenkins is available. Configuring Jenkins URL..."

# Set Jenkins URL via Jenkins CLI
# First, get the initial admin password
JENKINS_INITIAL_ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)

# Wait for Jenkins CLI to be available
echo "Waiting for Jenkins CLI to be available..."
until curl -s --head http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar > /dev/null; do
  sleep 5
done
echo "Jenkins CLI is available."

# Download jenkins-cli.jar
curl -s -o /tmp/jenkins-cli.jar http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar

# Set the Jenkins URL
# Note: This command assumes Jenkins is running and accessible on 127.0.0.1:8080
# and that the admin password is correct.
echo "Setting Jenkins URL to https://${var.domain_name}..."
java -jar /tmp/jenkins-cli.jar -s http://127.0.0.1:8080/ -auth admin:"$JENKINS_INITIAL_ADMIN_PASSWORD" \
  set-jenkins-url "https://${var.domain_name}/" || {
  echo "Failed to set Jenkins URL. Check Jenkins logs for details."
}
# --- END: Configure Jenkins URL ---

echo "Jenkins LTS installation and setup script completed."
