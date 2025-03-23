#!/bin/bash
# CloudSecure GitHub Actions Deployment Script
# This script is called directly from GitHub Actions

# Exit on any error
set -e

# Configuration (these are set by GitHub Actions Environment Variables)
# SERVER_IP, SSH_USER, and SSH_PRIVATE_KEY should be set in GitHub Secrets

echo "==== CloudSecure GitHub Actions Deployment ===="
echo "Server: $SERVER_IP"
echo "User: $SSH_USER"
echo "App Directory: /opt/cloudsecure"

# Setup SSH
mkdir -p ~/.ssh
echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-keyscan -H "$SERVER_IP" >> ~/.ssh/known_hosts

# SSH options for secure connection
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=no"

# Create the deployment script to run on the server
cat > deploy_script.sh << 'EOF'
#!/bin/bash
# This script runs on the remote server

# Exit on any error
set -e

# Application directory
APP_DIR="/opt/cloudsecure"

echo "=== Creating application directory ==="
sudo mkdir -p $APP_DIR
sudo chown -R $(whoami):$(whoami) $APP_DIR
sudo chmod -R 755 $APP_DIR

echo "=== Installing dependencies ==="
sudo yum update -y
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $(whoami)

echo "=== Installing Docker Compose ==="
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "=== Creating deployment files ==="
mkdir -p $APP_DIR/html

cat > $APP_DIR/docker-compose.yml << 'COMPOSE_EOF'
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
COMPOSE_EOF

cat > $APP_DIR/html/index.html << 'HTML_EOF'
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
HTML_EOF

echo "=== Starting application ==="
cd $APP_DIR
/usr/local/bin/docker-compose up -d

echo "=== Checking deployment status ==="
/usr/local/bin/docker-compose ps

echo "=== Deployment completed successfully! ==="
EOF

# Make the deployment script executable
chmod +x deploy_script.sh

# Copy the deployment script to the server
scp $SSH_OPTS -i ~/.ssh/id_rsa deploy_script.sh "${SSH_USER}@${SERVER_IP}:~/"

# Execute the deployment script on the server
ssh $SSH_OPTS -i ~/.ssh/id_rsa "${SSH_USER}@${SERVER_IP}" "bash ./deploy_script.sh"

echo "CloudSecure deployment completed successfully!"