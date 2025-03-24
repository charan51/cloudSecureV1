provider "aws" {
  region = "us-east-1" # You can change this to your preferred region
}
data "aws_security_group" "cloudsecure_sg" {
  name = "cloudsecure-sg-20250323224930"
}
resource "aws_instance" "cloudsecure" {
  count         = var.instance_count
  ami           = "ami-0230bd60aa48260c6" # Ubuntu 22.04 LTS AMI (us-east-1, free tier eligible)
  instance_type = "t2.micro"             # Free tier eligible
  key_name      = "cloudsecure-key"      # You'll need to create this key pair in AWS
  vpc_security_group_ids = [data.aws_security_group.cloudsecure_sg.id]
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

  # Check if instance is running, if not create one
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "cloudsecure_sg" {
  name        = "cloudsecure-sg"
  description = "Security group for CloudSecure app"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this in production
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

variable "instance_count" {
  default = 1
}

output "instance_ip" {
  value = aws_instance.cloudsecure[0].public_ip
}