output "repository_url" {
  description = "URL of the pass ECR repository."
  value       = aws_ecr_repository.pass.repository_url
}

output "repository_arn" {
  description = "ARN of the pass ECR repository."
  value       = aws_ecr_repository.pass.arn
}
