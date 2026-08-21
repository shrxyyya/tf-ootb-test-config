output "domain_endpoint" {
  description = "Endpoint of the pass OpenSearch domain."
  value       = aws_opensearch_domain.pass.endpoint
}

output "domain_arn" {
  description = "ARN of the pass OpenSearch domain."
  value       = aws_opensearch_domain.pass.arn
}

output "security_group_id" {
  description = "ID of the shared OpenSearch security group."
  value       = aws_security_group.opensearch.id
}
