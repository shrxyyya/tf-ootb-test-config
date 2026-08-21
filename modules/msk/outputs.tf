output "cluster_arn" {
  description = "ARN of the pass MSK cluster."
  value       = aws_msk_cluster.pass.arn
}

output "bootstrap_brokers_tls" {
  description = "TLS bootstrap broker endpoints of the pass MSK cluster."
  value       = aws_msk_cluster.pass.bootstrap_brokers_tls
}

output "security_group_id" {
  description = "ID of the shared MSK security group."
  value       = aws_security_group.msk.id
}
