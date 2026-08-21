output "app_security_group_id" {
  description = "ID of the pass application security group (used by other modules)."
  value       = aws_security_group.app_pass.id
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group receiving VPC flow logs."
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "launch_template_id" {
  description = "ID of the pass launch template."
  value       = aws_launch_template.pass.id
}
