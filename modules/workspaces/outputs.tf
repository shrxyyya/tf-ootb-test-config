output "workspace_id" {
  description = "ID of the pass WorkSpaces workspace."
  value       = aws_workspaces_workspace.pass.id
}

output "directory_id" {
  description = "ID of the Simple AD directory used by WorkSpaces."
  value       = aws_directory_service_directory.main.id
}
