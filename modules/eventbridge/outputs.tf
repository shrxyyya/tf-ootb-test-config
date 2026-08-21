output "event_bus_arn" {
  description = "ARN of the compliant (pass) custom event bus."
  value       = aws_cloudwatch_event_bus.pass.arn
}

output "event_bus_name" {
  description = "Name of the compliant (pass) custom event bus."
  value       = aws_cloudwatch_event_bus.pass.name
}
