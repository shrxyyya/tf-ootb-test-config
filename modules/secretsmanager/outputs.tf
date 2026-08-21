output "secret_arn" {
  description = "ARN of the pass secret."
  value       = aws_secretsmanager_secret.pass.arn
}
