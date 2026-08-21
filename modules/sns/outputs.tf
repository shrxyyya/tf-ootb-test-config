output "topic_arn" {
  description = "ARN of the pass SNS topic."
  value       = aws_sns_topic.pass.arn
}
