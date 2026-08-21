output "alb_arn" {
  description = "ARN of the pass (compliant) ALB."
  value       = aws_lb.pass.arn
}

output "alb_dns_name" {
  description = "DNS name of the pass (compliant) ALB."
  value       = aws_lb.pass.dns_name
}

output "alb_security_group_id" {
  description = "ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the shared application target group."
  value       = aws_lb_target_group.app.arn
}
