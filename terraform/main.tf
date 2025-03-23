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

  # Allow SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

# Create EC2 instance in the default VPC
resource "aws_instance" "cloudsecure_server" {
  ami                         = var.aws_ami_id
  instance_type               = var.aws_instance_type
  key_name                    = var.aws_key_name
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.cloudsecure_sg.id]
  associate_public_ip_address = true

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
              # Update system
              yum update -y
              yum install -y docker git

              # Configure SSH for faster availability
              sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
              sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
              systemctl restart sshd

              # Configure Docker
              systemctl start docker
              systemctl enable docker
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              # Signal that the instance is ready
              touch /tmp/instance-ready
              EOF
}