#!/bin/bash
sudo apt update
sudo apt install -y curl nginx unzip

curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt install -y nodejs

sudo npm install -g ghost-cli@latest

sudo mkdir -p /var/www/ghost
sudo chown -R $USER:$USER /var/www/ghost
cd /var/www/ghost
ghost install local --port 80 --no-setup-linux-user --no-prompt
