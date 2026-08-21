output "vpc_id" {
  description = "ID of the shared VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the three private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the three public subnets"
  value       = aws_subnet.public[*].id
}

output "availability_zones" {
  description = "Availability zones in use"
  value       = var.availability_zones
}

output "kms_shared_key_arn" {
  description = "ARN of the shared KMS CMK used by all service modules"
  value       = module.kms.shared_key_arn
}

output "eks_cluster_name" {
  description = "Name of the pass EKS cluster"
  value       = module.eks.cluster_name
}

output "ecs_cluster_name" {
  description = "Name of the pass ECS cluster"
  value       = module.ecs.cluster_name
}

output "rds_instance_endpoint" {
  description = "Connection endpoint of the pass RDS DB instance"
  value       = module.rds.db_instance_endpoint
}

output "aurora_cluster_endpoint" {
  description = "Writer endpoint of the pass Aurora cluster"
  value       = module.rds.aurora_cluster_endpoint
}
