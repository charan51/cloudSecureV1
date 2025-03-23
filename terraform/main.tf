provider "aws" {
  region = var.aws_region
}

# Use default VPC and its resources instead of creating new ones
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  id = data.aws_subnets.default.ids[0]
}

# IAM role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "cloudsecure-ssm-role-${formatdate("YYMMDDhhmmss", timestamp())}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  tags = {
    Name = "cloudsecure-ssm-role"
  }
}

# Create Security Group in the default VPC
resource "aws_security_group" "cloudsecure_sg" {
  name        = var.security_group_name
  description = "Allow web and SSH traffic for CloudSecure"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH - ensure GitHub Actions runners can connect
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from anywhere for deployment"
  }

  # Allow server port
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudsecure-sg"
  }
}

# Find existing instances with the cloudsecure-server tag
data "aws_instances" "existing_cloudsecure" {
  filter {
    name   = "tag:Name"
    values = ["cloudsecure-server"]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running", "pending", "stopped"]
  }
}

locals {
  # Determine if we should create a new instance or use existing
  use_existing = length(data.aws_instances.existing_cloudsecure.ids) > 0
  instance_id = local.use_existing ? data.aws_instances.existing_cloudsecure.ids[0] : aws_instance.cloudsecure_server[0].id
}

# Get details about the existing instance if one is found
data "aws_instance" "existing_instance" {
  count       = local.use_existing ? 1 : 0
  instance_id = local.use_existing ? data.aws_instances.existing_cloudsecure.ids[0] : ""
}

# Create IAM instance profile for SSM
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "cloudsecure-ssm-profile-${formatdate("YYMMDDhhmmss", timestamp())}"
  role = aws_iam_role.ssm_role.name
}

# Create EC2 instance in the default VPC only if no existing instance
resource "aws_instance" "cloudsecure_server" {
  count                       = local.use_existing ? 0 : 1
  ami                         = var.aws_ami_id
  instance_type               = var.aws_instance_type
  key_name                    = var.aws_key_name
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.cloudsecure_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "cloudsecure-server"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "Starting user data script"
              
              # Update system
              echo "Updating system packages"
              yum update -y
              yum install -y docker git openssh-server
              
              # Create SSH key for ec2-user if it doesn't exist
              if [ ! -f /home/ec2-user/.ssh/authorized_keys ]; then
                echo "Creating SSH directory for ec2-user"
                mkdir -p /home/ec2-user/.ssh
                chmod 700 /home/ec2-user/.ssh
                touch /home/ec2-user/.ssh/authorized_keys
                chmod 600 /home/ec2-user/.ssh/authorized_keys
                chown -R ec2-user:ec2-user /home/ec2-user/.ssh
              fi
              
              # Configure SSH for easier access
              echo "Configuring SSH"
              echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
              echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
              echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
              echo "AuthorizedKeysFile .ssh/authorized_keys" >> /etc/ssh/sshd_config
              
              # Ensure SSH is enabled and running
              echo "Ensuring SSH is running"
              systemctl enable sshd
              systemctl start sshd
              systemctl restart sshd
              
              # Set a password for ec2-user and root for direct login
              echo "Setting passwords"
              echo "ec2-user:Password123!" | chpasswd
              echo "root:Password123!" | chpasswd
              
              # Configure Docker
              echo "Configuring Docker"
              systemctl start docker
              systemctl enable docker
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              # Signal that the instance is ready
              echo "User data script completed successfully"
              touch /tmp/instance-ready
              EOF
}