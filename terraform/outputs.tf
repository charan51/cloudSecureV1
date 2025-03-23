output "instance_id" {
  description = "ID of the EC2 instance"
  value       = local.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = local.use_existing ? data.aws_instance.existing_instance[0].public_ip : aws_instance.cloudsecure_server[0].public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = local.use_existing ? data.aws_instance.existing_instance[0].public_dns : aws_instance.cloudsecure_server[0].public_dns
}

output "is_new_instance" {
  description = "Indicates if a new instance was created or an existing one is being used"
  value       = local.use_existing ? "No - Using existing instance" : "Yes - Created new instance"
}