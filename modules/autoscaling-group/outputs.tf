output "asg_name" {
  description = "Name of the compliant (pass) Auto Scaling Group."
  value       = aws_autoscaling_group.pass.name
}

output "launch_template_id" {
  description = "ID of the compliant (pass) launch template."
  value       = aws_launch_template.pass.id
}

output "security_group_id" {
  description = "ID of the ASG security group."
  value       = aws_security_group.asg.id
}
