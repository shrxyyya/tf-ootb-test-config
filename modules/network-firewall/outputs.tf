output "firewall_arn" {
  description = "ARN of the pass Network Firewall."
  value       = aws_networkfirewall_firewall.pass.arn
}

output "policy_arn" {
  description = "ARN of the pass Network Firewall policy."
  value       = aws_networkfirewall_firewall_policy.pass.arn
}
