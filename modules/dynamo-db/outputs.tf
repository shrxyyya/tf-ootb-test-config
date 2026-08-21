output "table_id" {
  description = "Name/ID of the pass DynamoDB table."
  value       = aws_dynamodb_table.pass.id
}

output "table_arn" {
  description = "ARN of the pass DynamoDB table."
  value       = aws_dynamodb_table.pass.arn
}

output "dax_cluster_address" {
  description = "Cluster address of the pass DAX cluster."
  value       = aws_dax_cluster.pass.cluster_address
}
