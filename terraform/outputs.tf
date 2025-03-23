output "instance_ip" {
  value = aws_instance.security_ai.public_ip
}

output "instance_id" {
  value = aws_instance.security_ai.id
}