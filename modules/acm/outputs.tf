output "pca_arn" {
  description = "ARN of the pass PCA root CA."
  value       = aws_acmpca_certificate_authority.pass.arn
}

output "certificate_arn" {
  description = "ARN of the pass ACM certificate."
  value       = aws_acm_certificate.pass.arn
}
