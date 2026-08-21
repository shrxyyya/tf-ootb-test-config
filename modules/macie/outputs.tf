output "account_status" {
  description = "Current Macie account status (ENABLED = compliant, PAUSED = intentional violation)."
  value       = aws_macie2_account.main.status
}
