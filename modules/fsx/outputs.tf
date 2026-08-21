output "openzfs_filesystem_id" {
  description = "ID of the pass FSx OpenZFS file system."
  value       = aws_fsx_openzfs_file_system.pass.id
}

output "lustre_filesystem_id" {
  description = "ID of the pass FSx Lustre file system."
  value       = aws_fsx_lustre_file_system.pass.id
}
