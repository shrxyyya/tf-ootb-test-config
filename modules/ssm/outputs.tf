output "document_name" {
  description = "Name of the compliant (pass) SSM document."
  value       = aws_ssm_document.pass.name
}
