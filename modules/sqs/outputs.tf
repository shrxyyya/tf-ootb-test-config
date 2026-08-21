output "queue_url" {
  description = "URL of the pass SQS queue."
  value       = aws_sqs_queue.pass.id
}

output "queue_arn" {
  description = "ARN of the pass SQS queue."
  value       = aws_sqs_queue.pass.arn
}
