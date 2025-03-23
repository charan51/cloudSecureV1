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
               │       └─── Provision/Reuse EC2 Instance
               │
               └─── Deployment (Multi-layered approach)
                       ├─── Ansible (Primary method)
                       ├─── Direct SSH (Secondary method)
                       └─── AWS Systems Manager (Fallback method)
```

## Pipeline Components

### 1. GitHub Actions Workflows

#### Main CI/CD Workflow (.github/workflows/cicd.yml)

The workflow is triggered:
- On every push to the main branch
- Manually via workflow_dispatch

The workflow has two main jobs:
- **Test**: Runs the client-side tests
- **Deploy**: Provisions infrastructure and deploys the application

#### Teardown Workflow (.github/workflows/teardown.yml)

Manually triggered workflow to tear down AWS resources:
- Stops running containers
- Destroys Terraform-managed resources
- Verifies cleanup completion

### 2. Terraform (terraform/)

Infrastructure as Code to provision AWS resources:
- Uses default VPC to avoid VPC limits on free tier accounts
- Security group allowing HTTP, HTTPS, SSH, and application ports
- EC2 instance (t2.micro, free tier eligible)
- IAM role for Systems Manager connectivity
- Capable of reusing existing instances to reduce cost

### 3. Ansible (ansible/)

Configuration management to:
- Update system packages
- Install required software (Docker, Git)
- Configure Docker and Docker Compose
- Copy application files
- Build and run Docker containers

### 4. Fallback Methods

The pipeline includes multiple deployment approaches:
1. **Ansible Playbook**: Primary method using standard configuration management
2. **Direct SSH Deployment**: Fallback using raw SSH commands if Ansible fails
3. **AWS Systems Manager**: Final fallback that doesn't require SSH connectivity

## Requirements

### Required Secrets

You must add these secrets to your GitHub repository:

1. **AWS_ACCESS_KEY_ID**: Your AWS access key
2. **AWS_SECRET_ACCESS_KEY**: Your AWS secret key
3. **SSH_PRIVATE_KEY**: The private key (PEM file) for SSH access to EC2

### AWS Setup

1. Create a key pair named `cloudsecure-key` in your AWS account
2. Create an IAM user with programmatic access and the following permissions:
   - AmazonEC2FullAccess
   - AmazonSSMFullAccess
   - IAMFullAccess (or more limited permissions to manage roles/profiles)
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
   - Attempts deployment with multiple strategies:
     - Ansible playbook (primary)
     - Direct SSH deployment script (if Ansible fails)
     - AWS Systems Manager (if SSH connectivity fails)
   - Verifies deployment success

## Multiple Deployment Approaches

The CI/CD pipeline uses a layered approach for maximum reliability:

### 1. Ansible Deployment
The preferred method, using structured playbooks for configuration management.

### 2. Direct SSH Deployment
If Ansible fails, the pipeline falls back to direct SSH commands using `deploy.sh`.

### 3. AWS Systems Manager Deployment
If SSH connectivity fails, the pipeline uses AWS Systems Manager (SSM) which doesn't require SSH access.

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

## Managing Resources

### Intelligent Resource Management

The pipeline is designed to minimize AWS costs:
- It will detect and reuse existing instances tagged with "cloudsecure-server"
- The terraform output will indicate whether a new instance was created

### Manual Resource Teardown

To remove all AWS resources when not needed:
1. Go to the "Actions" tab in your GitHub repository
2. Select the "CloudSecure Infrastructure Teardown" workflow
3. Click "Run workflow"
4. Type "CONFIRM" in the input field and click "Run workflow"

## Troubleshooting

### Failed SSH Connection

If the SSH connection fails:
1. The workflow will attempt multiple users (ec2-user, ubuntu, admin, root)
2. Ensure the key pair name in AWS matches the one in Terraform variables
3. Check security group rules to ensure port 22 is open
4. Verify the SSH private key in GitHub secrets matches the key pair in AWS

### Failed Ansible Deployment

If Ansible deployment fails:
1. The workflow will automatically try direct SSH deployment as a fallback
2. Check Ansible logs in the workflow output for specific errors
3. Ansible inventory file should match the SSH user for your AMI (ec2-user for Amazon Linux)

### Failed Direct SSH Deployment

If both Ansible and direct SSH deployment fail:
1. The workflow will attempt to use AWS Systems Manager (SSM) as a final fallback
2. Check that the instance has an IAM role with SSM permissions
3. Ensure the instance has internet connectivity to reach SSM endpoints

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

To minimize costs when not in use, run the teardown workflow.