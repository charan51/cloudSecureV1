provider "aws" {
  region = var.aws_region
}

provider "random" {
}

# Generate a random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Use existing default VPC
data "aws_vpc" "existing_vpc" {
  default = true
}

# Find default subnet in the first AZ
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
}

data "aws_subnet" "default" {
  id = tolist(data.aws_subnets.default.ids)[0]
}

# Use existing security group or create a new one
resource "aws_security_group" "cloudsecure_sg" {
  name        = "cloudsecure-sg-${random_id.suffix.hex}"
  description = "Allow SSH, HTTP, and application ports"
  vpc_id      = data.aws_vpc.existing_vpc.id

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
    Name = "cloudsecure-sg-${random_id.suffix.hex}"
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
  key_name   = "cloudsecure-key-${random_id.suffix.hex}"
  public_key = var.ssh_public_key
}

resource "aws_instance" "cloudsecure_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.cloudsecure_key.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.cloudsecure_sg.id]
  
  root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }

  tags = {
    Name = "cloudsecure-instance-${random_id.suffix.hex}"
  }
} 