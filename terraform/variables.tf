variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "ec2_ami" {
  description = "Amazon Linux 2 AMI ID"
  default     = "ami-0e8a34246278c21e4" # Amazon Linux 2023 AMI
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro" # Free tier eligible
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instance"
  type        = string
} 