provider "aws" {
  region = var.aws_region
}

# Create VPC
resource "aws_vpc" "cloudsecure_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cloudsecure-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "cloudsecure_igw" {
  vpc_id = aws_vpc.cloudsecure_vpc.id

  tags = {
    Name = "cloudsecure-igw"
  }
}

# Create Public Subnet
resource "aws_subnet" "cloudsecure_subnet" {
  vpc_id                  = aws_vpc.cloudsecure_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "cloudsecure-subnet"
  }
}

# Create Route Table
resource "aws_route_table" "cloudsecure_rtb" {
  vpc_id = aws_vpc.cloudsecure_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudsecure_igw.id
  }

  tags = {
    Name = "cloudsecure-rtb"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "cloudsecure_rta" {
  subnet_id      = aws_subnet.cloudsecure_subnet.id
  route_table_id = aws_route_table.cloudsecure_rtb.id
}

# Create Security Group
resource "aws_security_group" "cloudsecure_sg" {
  name        = "cloudsecure-sg"
  description = "Allow web and SSH traffic"
  vpc_id      = aws_vpc.cloudsecure_vpc.id

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

# Create EC2 instance
resource "aws_instance" "cloudsecure_server" {
  ami                         = var.aws_ami_id
  instance_type               = var.aws_instance_type
  key_name                    = var.aws_key_name
  subnet_id                   = aws_subnet.cloudsecure_subnet.id
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
              yum update -y
              yum install -y docker git
              systemctl start docker
              systemctl enable docker
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              EOF
}