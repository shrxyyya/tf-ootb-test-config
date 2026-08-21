output "replication_instance_arn" {
  description = "ARN of the pass DMS replication instance."
  value       = aws_dms_replication_instance.pass.replication_instance_arn
}
