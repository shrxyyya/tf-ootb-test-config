output "vault_arn" {
  description = "ARN of the compliant (pass) backup vault."
  value       = aws_backup_vault.pass.arn
}

output "plan_arn" {
  description = "ARN of the compliant (pass) backup plan."
  value       = aws_backup_plan.pass.arn
}
