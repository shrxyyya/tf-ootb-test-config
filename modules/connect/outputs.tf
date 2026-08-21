output "instance_id" {
  description = "ID of the pass Connect instance."
  value       = aws_connect_instance.pass.id
}

output "instance_arn" {
  description = "ARN of the pass Connect instance."
  value       = aws_connect_instance.pass.arn
}
