#!/bin/bash
sudo apt update
sudo apt install -y curl unzip

# Install Node.js (Ghost recommends Node 18 LTS)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt install -y nodejs

# Install Ghost CLI
sudo npm install -g ghost-cli@latest

# Set up Ghost directory
sudo mkdir -p /var/www/ghost
sudo chown -R $USER:$USER /var/www/ghost
cd /var/www/ghost

# Install Ghost to run directly on port 80
ghost install local --port 80 --no-setup-linux-user --no-prompt
