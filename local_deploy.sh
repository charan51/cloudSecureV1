#!/bin/bash
# Local Deployment Script for CloudSecure
# Run this script from your local machine

# Set variables
SERVER_IP=""
SSH_USER="ec2-user"
SSH_KEY=""

# Color codes for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Show help message
function show_help {
  echo "CloudSecure Local Deployment Script"
  echo 
  echo "Usage: $0 -i SERVER_IP -k SSH_KEY_PATH [-u SSH_USER]"
  echo
  echo "Example: $0 -i 3.236.212.70 -k ~/.ssh/my-key.pem -u ec2-user"
  echo
  echo "Options:"
  echo "  -i  Server IP address (required)"
  echo "  -k  Path to SSH private key file (required)"
  echo "  -u  SSH username (default: ec2-user)"
  echo "  -h  Show this help message"
  echo
  exit 1
}

# Process arguments
while getopts "i:k:u:h" opt; do
  case ${opt} in
    i )
      SERVER_IP=$OPTARG
      ;;
    k )
      SSH_KEY=$OPTARG
      ;;
    u )
      SSH_USER=$OPTARG
      ;;
    h )
      show_help
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      show_help
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      show_help
      ;;
  esac
done

# Check required parameters
if [[ -z "$SERVER_IP" || -z "$SSH_KEY" ]]; then
  echo -e "${RED}Error: Missing required parameters${NC}"
  show_help
fi

# Check if SSH key file exists
if [ ! -f "$SSH_KEY" ]; then
  echo -e "${RED}Error: SSH key file not found: $SSH_KEY${NC}"
  exit 1
fi

# Configure SSH options
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=no"

# Check SSH connection
echo -e "${YELLOW}Testing SSH connection to $SERVER_IP...${NC}"
if ssh $SSH_OPTS $SSH_USER@$SERVER_IP "echo Connection successful"; then
  echo -e "${GREEN}SSH connection established!${NC}"
else
  echo -e "${RED}Failed to connect to the server. Please check your credentials and try again.${NC}"
  exit 1
fi

# Create a simple installation script
cat > /tmp/cloudsecure_install.sh << 'EOF'
#!/bin/bash
# CloudSecure Installation Script
# This script runs on the remote server

# Set variables
APP_DIR="/opt/cloudsecure"
LOG_FILE="/tmp/cloudsecure_install.log"

# Start logging
exec > >(tee -a $LOG_FILE) 2>&1
echo "=== CloudSecure Installation - $(date) ==="
echo "=== Server: $(hostname) ==="

echo "=== Creating application directory ==="
sudo mkdir -p $APP_DIR
sudo chown $(whoami):$(whoami) $APP_DIR
chmod 755 $APP_DIR
cd $APP_DIR

echo "=== Installing system dependencies ==="
sudo yum update -y
sudo yum install -y nginx

echo "=== Configuring web server ==="
mkdir -p $APP_DIR/html

# Create a simple HTML page
cat > $APP_DIR/html/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
  <title>CloudSecure</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background-color: #f7f9fc;
      line-height: 1.6;
      color: #333;
      max-width: 800px;
      margin: 40px auto;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 8px;
      padding: 30px;
      box-shadow: 0 2px 15px rgba(0,0,0,0.1);
    }
    h1 {
      color: #2c3e50;
      border-bottom: 2px solid #3498db;
      padding-bottom: 10px;
    }
    .info {
      background-color: #e7f4ff;
      padding: 15px;
      border-radius: 5px;
      margin-top: 20px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>CloudSecure Deployment</h1>
    <p>This is a placeholder page for the CloudSecure application.</p>
    
    <div class="info">
      <h3>Deployment Information</h3>
      <p><strong>Server:</strong> $(hostname)</p>
      <p><strong>IP Address:</strong> $(curl -s ifconfig.me)</p>
      <p><strong>Deployment Time:</strong> $(date)</p>
    </div>
  </div>
</body>
</html>
HTML_EOF

# Configure Nginx to serve our content
sudo cat > /tmp/cloudsecure.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    
    root /opt/cloudsecure/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX_EOF

sudo mv /tmp/cloudsecure.conf /etc/nginx/conf.d/cloudsecure.conf
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "=== Installation Complete ==="
echo "CloudSecure is now accessible at http://$(curl -s ifconfig.me)"
EOF

# Upload the installation script
echo -e "${YELLOW}Uploading installation script...${NC}"
scp $SSH_OPTS /tmp/cloudsecure_install.sh $SSH_USER@$SERVER_IP:/tmp/cloudsecure_install.sh

# Run the installation script
echo -e "${YELLOW}Running installation script on server...${NC}"
ssh $SSH_OPTS $SSH_USER@$SERVER_IP "chmod +x /tmp/cloudsecure_install.sh && /tmp/cloudsecure_install.sh"

# Final message
echo -e "${GREEN}Deployment completed!${NC}"
echo -e "You can access CloudSecure at: ${YELLOW}http://$SERVER_IP${NC}"