provider "aws" {
  region = "us-east-1"
}

resource "random_id" "sg_suffix" {
  byte_length = 4
}

resource "aws_security_group" "cloudsecure_sg" {
  name        = "cloudsecure-sg-${random_id.sg_suffix.hex}"
  description = "Security group for CloudSecure app"
  vpc_id      = "vpc-06ba180dc12d2a77a"

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

  ingress {
    from_port   = 3307
    to_port     = 3307
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "cloudsecure" {
  count         = var.instance_count
  ami           = "ami-0e86e20dae9224db8"
  instance_type = "t2.micro"
  key_name      = "cloudsecure-key"

  vpc_security_group_ids = [aws_security_group.cloudsecure_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "cloudsecure-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

variable "instance_count" {
  default = 1
}

output "instance_ip" {
  value = aws_instance.cloudsecure[0].public_ip
}