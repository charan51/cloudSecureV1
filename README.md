[![Board Status](https://dev.azure.com/SecureCloudAI/d27239a0-b12b-4e25-9029-df61b2cbfe8a/5ef994e1-ffd3-4a86-877d-034b98d5f027/_apis/work/boardbadge/05f6c1ff-9f74-492e-8a84-ed5c0acc1ffd)](https://dev.azure.com/SecureCloudAI/d27239a0-b12b-4e25-9029-df61b2cbfe8a/_boards/board/t/5ef994e1-ffd3-4a86-877d-034b98d5f027/Microsoft.RequirementCategory)
# CloudSecure
The increasing sophistication of cyber threats necessitates the integration of Artificial
Intelligence (AI) in cybersecurity solutions. This project aims to design and implement
an AI-driven cybersecurity framework leveraging cloud infrastructure, containerized
applications, and CI/CD pipelines to ensure seamless and automated security updates.
The solution will utilize AWS for cloud infrastructure, Kubernetes for orchestration, and
Ansible for configuration management and automation. Additionally, Figma will be used
for user experience modelling to enhance the usability of the cybersecurity tools
developed.

# Running the app

Check readme under app folder

# Deployment Guide

## CI/CD with GitHub Actions, Terraform and Ansible

The deployment process uses GitHub Actions to automatically test, provision infrastructure with Terraform, and deploy the application with Ansible.

### Setup Instructions

1. **Create GitHub Secrets**

   You need to add the following secrets to your GitHub repository:
   
   - `AWS_ACCESS_KEY_ID`: Your AWS access key ID
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key
   - `SSH_PRIVATE_KEY`: Your EC2 private key (the contents of your .pem file)

   To add these secrets:
   - Go to your GitHub repository
   - Click on "Settings" > "Secrets and variables" > "Actions"
   - Click "New repository secret" to add each secret
   
2. **AWS Setup**

   - Create a key pair named `cloudsecure-key` in your AWS account (us-east-1 region)
   - Create an IAM user with programmatic access and the following permissions:
     - AmazonEC2FullAccess
     - AmazonVPCFullAccess
   - Save the access key ID and secret access key as GitHub secrets

2. **Manual Deployment**

   If you need to deploy manually (without GitHub Actions):
   
   ```bash
   # Connect to your server
   ssh -i /path/to/your/key.pem ec2-user@your-server-ip
   
   # Create the application directory
   sudo mkdir -p /opt/cloudsecure
   sudo chmod 755 /opt/cloudsecure
   sudo chown ec2-user:ec2-user /opt/cloudsecure
   
   # Create a simple docker-compose.yml
   cat > /opt/cloudsecure/docker-compose.yml << 'EOF'
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
   
   # Create a basic HTML page
   mkdir -p /opt/cloudsecure/html
   echo "<html><body><h1>CloudSecure</h1></body></html>" > /opt/cloudsecure/html/index.html
   
   # Install Docker and Docker Compose
   sudo yum update -y
   sudo yum install -y docker
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker ec2-user
   
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   
   # Deploy with Docker Compose
   cd /opt/cloudsecure
   docker-compose up -d
   ```

## Security Warning

**IMPORTANT**: Never store sensitive files such as `.pem` private keys in your repository. 

If you've accidentally committed a `.pem` file to this repository:

1. Remove it immediately:
   ```bash
   git rm --cached your-key.pem
   echo "*.pem" >> .gitignore
   git commit -m "Remove sensitive key file and add to gitignore"
   git push
   ```

2. Consider the key compromised and generate a new key pair for your servers

# License 
Is under MIT
