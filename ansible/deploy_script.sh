#!/bin/bash
# CloudSecure deployment script

# Basic settings
APP_DIR="/opt/cloudsecure"
TEMP_DIR="/tmp/.ansible-tmp"

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 
    exit 1
fi

# Create temp directory
mkdir -p $TEMP_DIR
chmod 1777 $TEMP_DIR

# Print system info
echo "=== System Information ==="
uname -a
echo "Python version:"
python3 --version
cat /etc/os-release
echo "=========================="

# Install dependencies
echo "=== Installing Dependencies ==="
yum update -y
yum install -y curl git docker python3 python3-pip nodejs
echo "=== Dependencies Installed ==="

# Configure Docker
echo "=== Configuring Docker ==="
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
echo "=== Docker Configured ==="

# Create application directories
echo "=== Creating Application Directories ==="
mkdir -p $APP_DIR
mkdir -p $APP_DIR/app
mkdir -p $APP_DIR/app/client
mkdir -p $APP_DIR/app/server
mkdir -p $APP_DIR/backups
chmod -R 0755 $APP_DIR
chown -R ec2-user:ec2-user $APP_DIR
echo "=== Application Directories Created ==="

# Create a test file
echo "CloudSecure deployment completed successfully on $(date)" > $APP_DIR/deployment.log
chown ec2-user:ec2-user $APP_DIR/deployment.log

echo "=== Deployment Completed Successfully ==="
cat $APP_DIR/deployment.log