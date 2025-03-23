#!/bin/bash
# CloudSecure Direct Deployment Script
# This script deploys the application without using Ansible

# Configuration (change these values as needed)
SERVER_IP="44.200.105.112"
SSH_USER="ec2-user"
PEM_FILE="$HOME/.ssh/id_rsa"  # Change this to your key location
APP_DIR="/opt/cloudsecure"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==== CloudSecure Direct Deployment ====${NC}"
echo "Server: $SERVER_IP"
echo "User: $SSH_USER"
echo "App Directory: $APP_DIR"
echo

# Check if key file exists
if [ ! -f "$PEM_FILE" ]; then
  echo -e "${RED}Error: SSH key file ($PEM_FILE) not found${NC}"
  echo "Please set the correct path to your SSH key file"
  exit 1
fi

# SSH options to avoid known hosts issues
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=no"

# Function to execute command on remote server
run_ssh() {
  ssh $SSH_OPTS -i "$PEM_FILE" "${SSH_USER}@${SERVER_IP}" "$1"
}

# Function to execute command with sudo on remote server
run_ssh_sudo() {
  ssh $SSH_OPTS -i "$PEM_FILE" "${SSH_USER}@${SERVER_IP}" "sudo $1"
}

echo -e "${GREEN}Testing SSH connection...${NC}"
if run_ssh "echo Connection successful"; then
  echo -e "${GREEN}SSH connection established${NC}"
else
  echo -e "${RED}Failed to connect to server${NC}"
  exit 1
fi

echo -e "${GREEN}Checking environment...${NC}"
run_ssh "uname -a && python3 --version"

echo -e "${GREEN}Creating application directories...${NC}"
run_ssh_sudo "mkdir -p $APP_DIR"
run_ssh_sudo "chown -R $SSH_USER:$SSH_USER $APP_DIR"
run_ssh_sudo "chmod -R 755 $APP_DIR"

echo -e "${GREEN}Installing dependencies...${NC}"
run_ssh_sudo "yum update -y"
run_ssh_sudo "yum install -y docker git"
run_ssh_sudo "systemctl start docker"
run_ssh_sudo "systemctl enable docker"
run_ssh_sudo "usermod -aG docker $SSH_USER"

echo -e "${GREEN}Installing Docker Compose...${NC}"
run_ssh_sudo "curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
run_ssh_sudo "chmod +x /usr/local/bin/docker-compose"

echo -e "${GREEN}Creating simple deployment files...${NC}"
# Create a temporary directory
TEMP_DIR=$(mktemp -d)

# Create a simple docker-compose.yml
cat > "$TEMP_DIR/docker-compose.yml" << 'EOF'
version: '3'

services:
  web:
    image: nginx:alpine
    container_name: cloudsecure-web
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    restart: always
EOF

# Create a simple HTML file
mkdir -p "$TEMP_DIR/html"
cat > "$TEMP_DIR/html/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>CloudSecure</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 40px;
      background-color: #f7f9fc;
      color: #333;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
      background: white;
      padding: 30px;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
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
      <p><strong>Deployment Time:</strong> <span id="deploy-time"></span></p>
      <p><strong>Server:</strong> <span id="server-info"></span></p>
    </div>
    
    <script>
      document.getElementById('deploy-time').textContent = new Date().toLocaleString();
      document.getElementById('server-info').textContent = window.location.hostname;
    </script>
  </div>
</body>
</html>
EOF

# Copy files to server
echo -e "${GREEN}Copying files to server...${NC}"
scp $SSH_OPTS -i "$PEM_FILE" -r "$TEMP_DIR"/* "${SSH_USER}@${SERVER_IP}:$APP_DIR/"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Starting application...${NC}"
run_ssh "cd $APP_DIR && /usr/local/bin/docker-compose up -d"

echo -e "${GREEN}Checking deployment status...${NC}"
run_ssh "cd $APP_DIR && /usr/local/bin/docker-compose ps"

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}You can access the application at: http://$SERVER_IP${NC}"