output "shared_key_arn" {
  description = "ARN of the shared CMK used by other service modules."
  value       = aws_kms_key.shared.arn
}

output "shared_key_id" {
  description = "Key ID of the shared CMK."
  value       = aws_kms_key.shared.id
}

output "pass_key_arn" {
  description = "ARN of the KMS.3/CIS-3.6 pass key (rotation enabled)."
  value       = aws_kms_key.pass.arn
}
