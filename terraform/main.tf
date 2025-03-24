provider "aws" {
  region = "us-east-1"
}

# Reference the existing security group
data "aws_security_group" "cloudsecure_sg" {
  name   = "cloudsecure-sg"
  vpc_id = "vpc-06ba180dc12d2a77a"
}

resource "aws_instance" "cloudsecure" {
  count         = var.instance_count
  ami           = "ami-0e86e20dae9224db8" # Amazon Linux 2 AMI (us-east-1)
  instance_type = "t2.micro"
  key_name      = "cloudsecure-key"

  vpc_security_group_ids = [data.aws_security_group.cloudsecure_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
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