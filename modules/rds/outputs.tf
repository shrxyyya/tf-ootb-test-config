output "db_instance_id" {
  description = "ID of the pass RDS DB instance."
  value       = aws_db_instance.pass.id
}

output "db_instance_endpoint" {
  description = "Connection endpoint of the pass RDS DB instance."
  value       = aws_db_instance.pass.endpoint
}

output "db_security_group_id" {
  description = "ID of the shared RDS security group."
  value       = aws_security_group.rds.id
}

output "aurora_cluster_id" {
  description = "ID of the pass Aurora cluster."
  value       = aws_rds_cluster.pass.id
}

output "aurora_cluster_endpoint" {
  description = "Writer endpoint of the pass Aurora cluster."
  value       = aws_rds_cluster.pass.endpoint
}
