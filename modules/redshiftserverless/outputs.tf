output "namespace_name" {
  description = "Name of the pass Redshift Serverless namespace."
  value       = aws_redshiftserverless_namespace.pass.namespace_name
}

output "workgroup_name" {
  description = "Name of the pass Redshift Serverless workgroup."
  value       = aws_redshiftserverless_workgroup.pass.workgroup_name
}

output "workgroup_endpoint" {
  description = "Endpoint of the pass Redshift Serverless workgroup."
  value       = aws_redshiftserverless_workgroup.pass.endpoint
}
