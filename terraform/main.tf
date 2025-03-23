provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "cloudsecure_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "cloudsecure-vpc"
  }
}

resource "aws_subnet" "cloudsecure_subnet" {
  vpc_id                  = aws_vpc.cloudsecure_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "cloudsecure-subnet"
  }
}

resource "aws_internet_gateway" "cloudsecure_igw" {
  vpc_id = aws_vpc.cloudsecure_vpc.id
  tags = {
    Name = "cloudsecure-igw"
  }
}

resource "aws_route_table" "cloudsecure_route_table" {
  vpc_id = aws_vpc.cloudsecure_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudsecure_igw.id
  }
  tags = {
    Name = "cloudsecure-route-table"
  }
}

resource "aws_route_table_association" "cloudsecure_rta" {
  subnet_id      = aws_subnet.cloudsecure_subnet.id
  route_table_id = aws_route_table.cloudsecure_route_table.id
}

resource "aws_security_group" "cloudsecure_sg" {
  name        = "cloudsecure-sg"
  description = "Allow SSH, HTTP, and application ports"
  vpc_id      = aws_vpc.cloudsecure_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "cloudsecure_key" {
  key_name   = "cloudsecure-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "cloudsecure_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.cloudsecure_key.key_name
  subnet_id              = aws_subnet.cloudsecure_subnet.id
  vpc_security_group_ids = [aws_security_group.cloudsecure_sg.id]
  
  root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }

  tags = {
    Name = "cloudsecure-instance"
  }
} 