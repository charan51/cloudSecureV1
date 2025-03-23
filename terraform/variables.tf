variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "ec2_ami" {
  description = "Amazon Linux 2 AMI ID"
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (HVM), SSD Volume Type
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro" # Free tier eligible
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instance"
  type        = string
} 