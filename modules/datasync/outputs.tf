output "task_arn" {
  description = "ARN of the pass DataSync task."
  value       = aws_datasync_task.pass.arn
}
