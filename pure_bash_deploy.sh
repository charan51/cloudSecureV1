#!/bin/bash
# Pure Bash Deployment Script
# Works on Linux and macOS with SSH and the host IP

# Verify arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <server-ip> [username] [key-file]"
    echo "Example: $0 18.232.55.42 ec2-user ~/.ssh/my-key.pem"
    exit 1
fi

# Configuration
SERVER_IP="$1"
SSH_USER="${2:-ec2-user}"
KEY_FILE="${3:-~/.ssh/id_rsa}"
APP_DIR="/opt/cloudsecure"

echo "===== CloudSecure Pure Bash Deployment ====="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "Key File: $KEY_FILE"
echo "Target Directory: $APP_DIR"
echo

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "Error: SSH key file not found: $KEY_FILE"
    exit 1
fi

# Basic command for creating and running a simple web server
# Deliberately kept as simple as possible
REMOTE_COMMAND="
echo '===== Starting CloudSecure Deployment =====';
sudo mkdir -p $APP_DIR;
sudo chown \$USER:\$USER $APP_DIR;
cd $APP_DIR;

# Create a minimal HTML file
mkdir -p $APP_DIR/html;
cat > $APP_DIR/html/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
  <title>CloudSecure Deployment</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1 { color: #2c3e50; }
    .info { background: #f8f9fa; padding: 15px; border-radius: 5px; }
  </style>
</head>
<body>
  <h1>CloudSecure Deployment</h1>
  <p>This is a placeholder page for the CloudSecure application.</p>
  <div class='info'>
    <p>Deployed on: $(date)</p>
    <p>Server: $(hostname)</p>
  </div>
</body>
</html>
HTML_EOF

# Install and configure nginx as a simple server
sudo yum update -y;
sudo yum install -y nginx;
sudo systemctl start nginx;
sudo systemctl enable nginx;

# Configure nginx to serve our content
sudo mkdir -p /usr/share/nginx/html;
sudo cp $APP_DIR/html/index.html /usr/share/nginx/html/;
sudo systemctl restart nginx;

echo '===== Deployment Complete =====';
echo 'You can access the site at: http://$HOSTNAME or http://$(/usr/bin/curl -s ifconfig.me)';
"

# Execute the command on the remote server
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SERVER_IP" "$REMOTE_COMMAND"

echo "===== Deployment Completed ====="
echo "CloudSecure should now be accessible at: http://$SERVER_IP"