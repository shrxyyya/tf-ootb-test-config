output "cluster_id" {
  description = "Identifier of the pass DocumentDB cluster."
  value       = aws_docdb_cluster.pass.id
}

output "cluster_endpoint" {
  description = "Writer endpoint of the pass DocumentDB cluster."
  value       = aws_docdb_cluster.pass.endpoint
}

output "security_group_id" {
  description = "ID of the shared DocumentDB security group."
  value       = aws_security_group.docdb.id
}
