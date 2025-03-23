# CloudSecure CI/CD Documentation

This document outlines the CI/CD pipeline implemented for the CloudSecure application using GitHub Actions, Terraform, and Ansible.

## Architecture Overview

```
GitHub Repository
       │
       ▼
GitHub Actions Workflow
       │
       ├─── Test Stage
       │       └─── Run Client Tests
       │
       └─── Deployment Stage
               │
               ├─── Terraform (Infrastructure as Code)
               │       └─── Provision EC2 Instance
               │
               └─── Ansible (Configuration Management)
                       └─── Deploy Application
```

## Pipeline Components

### 1. GitHub Actions Workflow (.github/workflows/cicd.yml)

The workflow is triggered:
- On every push to the main branch
- Manually via workflow_dispatch

The workflow has two main jobs:
- **Test**: Runs the client-side tests
- **Deploy**: Provisions infrastructure and deploys the application

### 2. Terraform (terraform/)

Infrastructure as Code to provision AWS resources:
- VPC with internet gateway
- Public subnet
- Security group allowing HTTP, HTTPS, SSH, and application ports
- EC2 instance (t2.micro, free tier eligible)

### 3. Ansible (ansible/)

Configuration management to:
- Update system packages
- Install required software (Docker, Git)
- Configure Docker and Docker Compose
- Copy application files
- Build and run Docker containers

## Requirements

### Required Secrets

You must add these secrets to your GitHub repository:

1. **AWS_ACCESS_KEY_ID**: Your AWS access key
2. **AWS_SECRET_ACCESS_KEY**: Your AWS secret key
3. **SSH_PRIVATE_KEY**: The private key (PEM file) for SSH access to EC2

### AWS Setup

1. Create a key pair named `cloudsecure-key` in your AWS account
2. Create an IAM user with programmatic access and sufficient permissions
3. Store the credentials as GitHub secrets

## Workflow Process

1. **Test Phase**:
   - Checks out the code
   - Sets up Node.js
   - Installs dependencies
   - Runs client tests

2. **Deployment Phase**:
   - Sets up SSH key from GitHub secrets
   - Configures AWS credentials
   - Initializes and applies Terraform configuration
   - Captures the EC2 instance IP address
   - Updates Ansible hosts file with the IP address
   - Waits for SSH to become available
   - Runs Ansible playbook to deploy the application
   - Verifies deployment success

## Customization

### Changing AWS Region

To change the AWS region, modify `terraform/variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"  # Change this value
}
```

### Instance Type

To use a different EC2 instance type, modify `terraform/variables.tf`:

```hcl
variable "aws_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"  # Change this value
}
```

## Troubleshooting

### Failed Terraform Apply

If Terraform fails to apply:
1. Check AWS credentials
2. Verify you have sufficient permissions
3. Check the Terraform state and AWS console for any lingering resources

### Failed Ansible Deployment

If Ansible deployment fails:
1. Verify SSH connectivity to the instance
2. Check the SSH key permissions (should be 600)
3. Ensure the instance security group allows SSH access
4. Verify Docker is installed and running on the instance

## Security Best Practices

1. Use least privilege for IAM roles
2. Store secrets in GitHub Secrets, never in code
3. Update the security group to restrict access as needed
4. Regularly rotate AWS access keys
5. Monitor AWS CloudTrail for suspicious activity

## Cost Management

The configuration uses AWS free tier eligible resources, but always monitor:
- EC2 instance usage
- Data transfer costs
- Storage costs

To minimize costs when not in use, consider adding a workflow to tear down infrastructure.