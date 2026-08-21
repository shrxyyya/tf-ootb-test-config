output "domain_endpoint" {
  description = "Endpoint of the pass Elasticsearch domain."
  value       = aws_elasticsearch_domain.pass.endpoint
}

output "domain_arn" {
  description = "ARN of the pass Elasticsearch domain."
  value       = aws_elasticsearch_domain.pass.arn
}
