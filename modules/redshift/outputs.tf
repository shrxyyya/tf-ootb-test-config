output "cluster_id" {
  description = "Identifier of the pass Redshift cluster."
  value       = aws_redshift_cluster.pass.id
}

output "cluster_endpoint" {
  description = "Connection endpoint of the pass Redshift cluster."
  value       = aws_redshift_cluster.pass.endpoint
}

output "cluster_security_group_id" {
  description = "ID of the shared Redshift security group."
  value       = aws_security_group.redshift.id
}
