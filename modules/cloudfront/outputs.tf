output "distribution_id" {
  description = "ID of the pass CloudFront distribution."
  value       = aws_cloudfront_distribution.pass.id
}

output "distribution_domain_name" {
  description = "Domain name of the pass CloudFront distribution."
  value       = aws_cloudfront_distribution.pass.domain_name
}

output "origin_bucket_id" {
  description = "ID of the S3 origin bucket."
  value       = aws_s3_bucket.origin.id
}
