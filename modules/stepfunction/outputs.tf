output "state_machine_arn" {
  description = "ARN of the compliant (pass) Step Functions state machine."
  value       = aws_sfn_state_machine.pass.arn
}
