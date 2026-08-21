output "ec2_instance_profile_name" {
  description = "Name of the shared EC2 instance profile (wraps the SSM-enabled instance role)."
  value       = aws_iam_instance_profile.ec2_pass.name
}

output "rds_monitoring_role_arn" {
  description = "ARN of the RDS enhanced monitoring role."
  value       = aws_iam_role.rds_monitoring.arn
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster service role."
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS managed node group role."
  value       = aws_iam_role.eks_node.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda VPC execution role."
  value       = aws_iam_role.lambda_execution.arn
}

output "cloudtrail_cloudwatch_role_arn" {
  description = "ARN of the CloudTrail → CloudWatch Logs delivery role."
  value       = aws_iam_role.cloudtrail_cloudwatch.arn
}
