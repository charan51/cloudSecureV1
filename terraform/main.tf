provider "aws" {
  region = "us-east-1"
}

# Reference the existing security group
data "aws_security_group" "cloudsecure_sg" {
  name   = "cloudsecure-sg"
  vpc_id = "vpc-06ba180dc12d2a77a"
}

# Check for existing instances with the tag Name=cloudsecure-instance
data "aws_instances" "existing_instances" {
  instance_tags = {
    Name = "cloudsecure-instance"
  }

  # Optional: Filter by instance state (e.g., only running instances)
  instance_state_names = ["running"]
}

# Create EC2 instance only if no existing instances are found
resource "aws_instance" "cloudsecure" {
  # Create the instance only if no running instances with the tag exist
  count         = length(data.aws_instances.existing_instances.ids) == 0 ? var.instance_count : 0
  ami           = "ami-0e4d9ed95865f3b40" # Amazon Linux 2 AMI (us-east-1)
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
  # Use the first instance's public IP if created, otherwise null
  value = length(aws_instance.cloudsecure) > 0 ? aws_instance.cloudsecure[0].public_ip : (length(data.aws_instances.existing_instances.public_ips) > 0 ? data.aws_instances.existing_instances.public_ips[0] : null)
}