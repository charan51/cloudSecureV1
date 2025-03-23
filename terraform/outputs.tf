output "instance_ip" {
  value = aws_instance.security_ai.public_ip
}

output "instance_id" {
  value = aws_instance.security_ai.id
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}