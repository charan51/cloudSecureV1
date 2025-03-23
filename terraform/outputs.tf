output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.cloudsecure_instance.public_ip
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.cloudsecure_instance.id
} 