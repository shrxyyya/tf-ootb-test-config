output "workgroup_name" {
  description = "Name of the pass Athena workgroup."
  value       = aws_athena_workgroup.pass.name
}
