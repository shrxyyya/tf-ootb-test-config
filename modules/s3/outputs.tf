output "app_data_bucket_id" {
  description = "ID of the pass app-data bucket."
  value       = aws_s3_bucket.app_data_pass.id
}

output "app_data_bucket_arn" {
  description = "ARN of the pass app-data bucket."
  value       = aws_s3_bucket.app_data_pass.arn
}

output "logs_bucket_id" {
  description = "ID of the dedicated access-logging bucket."
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the dedicated access-logging bucket."
  value       = aws_s3_bucket.logs.arn
}
