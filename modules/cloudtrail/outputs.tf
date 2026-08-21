output "trail_arn" {
  description = "ARN of the compliant (pass) CloudTrail trail."
  value       = aws_cloudtrail.pass.arn
}

output "trail_logs_bucket_id" {
  description = "ID of the S3 bucket receiving CloudTrail log files."
  value       = aws_s3_bucket.trail_logs.id
}

output "trail_log_group_name" {
  description = "Name of the CloudWatch log group receiving CloudTrail events."
  value       = aws_cloudwatch_log_group.trail.name
}
