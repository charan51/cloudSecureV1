variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_ami_id" {
  description = "AMI ID for EC2 instance (Amazon Linux 2)"
  type        = string
  default     = "ami-0230bd60aa48260c6"  # Amazon Linux 2023 AMI in us-east-1
}

variable "aws_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"  # Free tier eligible
}

variable "aws_key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "cloudsecure-key"  # Make sure this key exists in your AWS account
}

variable "security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = "cloudsecure-sg"
}