output "cluster_arn" {
  description = "ARN of the pass ECS cluster."
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the pass ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "task_definition_arn" {
  description = "ARN of the pass task definition."
  value       = aws_ecs_task_definition.pass.arn
}
