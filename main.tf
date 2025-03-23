terraform {
  required_version = ">= 1.7.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.91.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Environment = "dev"
      Terraform   = "true"
      Project     = "security-ai"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"]
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_instance" "security_ai" {
  ami           = "ami-08b5b3a93ed654d19" # Replace with latest if needed
  instance_type = "t2.micro"
  key_name      = "cloudsecure"
  
  iam_instance_profile = aws_iam_instance_profile.security_ai.name
  
  vpc_security_group_ids = [aws_security_group.security_ai.id]
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io python3 python3-pip
              systemctl start docker
              systemctl enable docker
              mkdir -p /opt/security-ai/app
              EOF

  tags = {
    Name = "Security-AI-Instance"
  }

  root_block_device {
    encrypted = true
  }
}

resource "aws_security_group" "security_ai" {
  name        = "security-ai-sg-${random_id.suffix.hex}"
  description = "Security group for AI threat detection instance"

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security-ai-sg"
  }
}

# IAM role for EC2 instance
resource "aws_iam_role" "ec2_role" {
  name = "security-ai-ec2-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach S3 read policy for deployment artifacts
resource "aws_iam_role_policy_attachment" "ec2_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Create instance profile for EC2
resource "aws_iam_instance_profile" "security_ai" {
  name = "security-ai-instance-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

# S3 bucket for SSH keys and other secrets
resource "aws_s3_bucket" "secrets_bucket" {
  bucket = "security-ai-secrets-${random_id.suffix.hex}"
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "secrets_bucket" {
  bucket = aws_s3_bucket.secrets_bucket.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "secrets_bucket" {
  bucket = aws_s3_bucket.secrets_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "instance_ip" {
  value = aws_instance.security_ai.public_ip
}

data "aws_region" "current" {}