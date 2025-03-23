variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-west-2"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instance"
  type        = string
}