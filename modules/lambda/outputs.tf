output "function_name" {
  description = "Name of the pass Lambda function."
  value       = aws_lambda_function.pass.function_name
}

output "function_arn" {
  description = "ARN of the pass Lambda function."
  value       = aws_lambda_function.pass.arn
}

output "security_group_id" {
  description = "ID of the Lambda security group."
  value       = aws_security_group.lambda.id
}
