# Configure the Terraform backend
terraform {
  backend "s3" {
    bucket         = "terraform-state-418295714127"
    key            = "cloudsecure/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}

# Provider configuration
provider "aws" {
  region = "us-east-1"
}

# Random suffix for resource names to avoid naming conflicts
resource "random_id" "suffix" {
  byte_length = 8
}

# S3 bucket for storing secrets (e.g., SSH key)
resource "aws_s3_bucket" "secrets_bucket" {
  bucket = "security-ai-secrets-${random_id.suffix.hex}"

  tags = {
    Name = "security-ai-secrets"
  }
}

# Make the S3 bucket private
resource "aws_s3_bucket_public_access_block" "secrets_bucket_access" {
  bucket = aws_s3_bucket.secrets_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for the EC2 instance (used for accessing S3 or other AWS services if needed)
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

  tags = {
    Name = "security-ai-ec2-role"
  }
}

# IAM policy for the EC2 role (e.g., S3 access if needed)
resource "aws_iam_role_policy" "ec2_policy" {
  name = "security-ai-ec2-policy-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.secrets_bucket.arn,
          "${aws_s3_bucket.secrets_bucket.arn}/*"
        ]
        Effect = "Allow"
      }
    ]
  })
}

# Attach the role to an instance profile for the EC2 instance
resource "aws_iam_instance_profile" "security_ai" {
  name = "security-ai-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

# Security group for the EC2 instance
resource "aws_security_group" "security_ai" {
  name        = "security-ai-sg-${random_id.suffix.hex}"
  description = "Security group for AI threat detection instance"

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

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.30.252.0/22"] # GitHub Actions IP range
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

# EC2 instance for hosting the application
resource "aws_instance" "security_ai" {
  ami                    = "ami-08b5b3a93ed654d19" # Ubuntu 20.04 in us-east-1
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.security_ai.name
  vpc_security_group_ids = [aws_security_group.security_ai.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y docker.io python3-pip
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu
              sudo mkdir -p /opt/security-ai/app
              sudo chown ubuntu:ubuntu /opt/security-ai/app
              EOF

  tags = {
    Name = "security-ai-instance"
  }
}

# OIDC Identity Provider for GitHub Actions (commented out since it already exists)
# resource "aws_iam_openid_connect_provider" "github" {
#   url = "https://token.actions.githubusercontent.com"
#
#   client_id_list = [
#     "sts.amazonaws.com"
#   ]
#
#   thumbprint_list = [
#     "74f3a68f16524f15424927704c9506f55a9316bd"
#   ]
# }

# IAM Role for GitHub Actions to assume
resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::418295714127:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:charan51/cloudSecureV1:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name = "GitHubActionsRole"
  }
}

# IAM Policy for GitHub Actions role
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "GitHubActionsPolicy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:CreateBucket",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutObject",
          "s3:DeleteBucket",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy"
        ]
        Resource = [
          "arn:aws:s3:::security-ai-secrets-*",
          "arn:aws:s3:::security-ai-secrets-*/*"
        ]
        Effect = "Allow"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::terraform-state-418295714127/cloudsecure/terraform.tfstate"
        Effect = "Allow"
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:418295714127:table/terraform-locks"
        Effect = "Allow"
      },
      {
        Action = [
          "ec2:*",
          "iam:CreateRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:PassRole",
          "iam:GetRole",
          "iam:GetInstanceProfile",
          "iam:ListRoles",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreateInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:TagRole",
          "iam:TagOpenIDConnectProvider"
        ]
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}