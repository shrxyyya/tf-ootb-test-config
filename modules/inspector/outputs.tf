output "resource_types_enabled" {
  description = "Inspector2 resource types currently enabled (empty list = intentional violation)."
  value       = var.create_failing_resources ? [] : ["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"]
}
