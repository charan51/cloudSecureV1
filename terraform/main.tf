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

# S3 bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "security-ai-pipeline-artifacts-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_ownership_controls" "codepipeline_bucket" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "security-ai-codepipeline-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "security-ai-codepipeline-policy-${random_id.suffix.hex}"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ],
        Effect = "Allow"
      },
      {
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource = "*",
        Effect = "Allow"
      },
      {
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = aws_codestarconnections_connection.github.arn,
        Effect = "Allow"
      },
      {
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ],
        Resource = "*",
        Effect = "Allow"
      }
    ]
  })
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "security-ai-codebuild-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "security-ai-codebuild-policy-${random_id.suffix.hex}"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*",
        Effect = "Allow"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ],
        Effect = "Allow"
      },
      {
        Action = [
          "ec2:Describe*",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:CreateNetworkInterfacePermission"
        ],
        Resource = "*",
        Effect = "Allow"
      },
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:cloudsecure-ssh-key-*"
        ],
        Effect = "Allow"
      }
    ]
  })
}

# Add SSM permissions to the CodeBuild role
resource "aws_iam_role_policy" "codebuild_ssm_policy" {
  name = "security-ai-codebuild-ssm-policy-${random_id.suffix.hex}"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = [
          "arn:aws:ssm:us-east-1:418295714127:parameter/codebuild/*"
        ],
        Effect = "Allow"
      }
    ]
  })
}

# CodeBuild project
resource "aws_codebuild_project" "security_ai" {
  name          = "security-ai-build-${random_id.suffix.hex}"
  description   = "Build project for security AI application"
  service_role  = aws_iam_role.codebuild_role.arn
  
  artifacts {
    type = "CODEPIPELINE"
  }
  
  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    privileged_mode             = true
    
    environment_variable {
      name  = "INSTANCE_IP"
      value = aws_instance.security_ai.public_ip
    }
  }
  
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# CodePipeline
resource "aws_codepipeline" "security_ai" {
  name     = "security-ai-pipeline-${random_id.suffix.hex}"
  role_arn = aws_iam_role.codepipeline_role.arn
  
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }
  
  stage {
    name = "Source"
    
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "charan51/cloudSecureV1"
        BranchName       = "main"
      }
    }
  }
  
  stage {
    name = "Build"
    
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      
      configuration = {
        ProjectName = aws_codebuild_project.security_ai.name
      }
    }
  }
  
  stage {
    name = "Deploy"
    
    action {
      name             = "AnsibleDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      
      configuration = {
        ProjectName = aws_codebuild_project.security_ai.name
      }
    }
  }
}

# GitHub connection
resource "aws_codestarconnections_connection" "github" {
  name          = "security-ai-github-connection"
  provider_type = "GitHub"
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

# Attach AWS managed policy for CodeDeploy to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_codedeploy_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
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

# Grant CodeBuild access to the S3 bucket
resource "aws_iam_role_policy" "codebuild_s3_secrets_policy" {
  name = "security-ai-codebuild-s3-secrets-policy-${random_id.suffix.hex}"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "${aws_s3_bucket.secrets_bucket.arn}/*"
        ],
        Effect = "Allow"
      }
    ]
  })
}


data "aws_region" "current" {}