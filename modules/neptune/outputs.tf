output "cluster_id" {
  description = "Identifier of the pass Neptune cluster."
  value       = aws_neptune_cluster.pass.id
}

output "cluster_endpoint" {
  description = "Writer endpoint of the pass Neptune cluster."
  value       = aws_neptune_cluster.pass.endpoint
}

output "security_group_id" {
  description = "ID of the shared Neptune security group."
  value       = aws_security_group.neptune.id
}
