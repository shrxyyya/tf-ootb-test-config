output "security_configuration_name" {
  description = "Name of the pass EMR security configuration."
  value       = aws_emr_security_configuration.pass.name
}
