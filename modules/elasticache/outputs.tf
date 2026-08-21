output "replication_group_id" {
  description = "ID of the pass ElastiCache replication group."
  value       = aws_elasticache_replication_group.pass.id
}

output "primary_endpoint_address" {
  description = "Primary endpoint address of the pass ElastiCache replication group."
  value       = aws_elasticache_replication_group.pass.primary_endpoint_address
}

output "security_group_id" {
  description = "ID of the shared ElastiCache security group."
  value       = aws_security_group.elasticache.id
}
