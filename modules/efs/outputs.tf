output "file_system_id" {
  description = "ID of the pass EFS file system."
  value       = aws_efs_file_system.pass.id
}

output "file_system_arn" {
  description = "ARN of the pass EFS file system."
  value       = aws_efs_file_system.pass.arn
}

output "access_point_arn" {
  description = "ARN of the pass EFS access point."
  value       = aws_efs_access_point.pass.arn
}
