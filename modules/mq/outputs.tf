output "broker_arn" {
  description = "ARN of the pass MQ broker."
  value       = aws_mq_broker.pass.arn
}

output "broker_id" {
  description = "ID of the pass MQ broker."
  value       = aws_mq_broker.pass.id
}
