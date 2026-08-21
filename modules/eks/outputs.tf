output "cluster_name" {
  description = "Name of the pass EKS cluster."
  value       = aws_eks_cluster.pass.name
}

output "cluster_endpoint" {
  description = "API server endpoint of the pass EKS cluster."
  value       = aws_eks_cluster.pass.endpoint
}

output "cluster_security_group_id" {
  description = "ID of the EKS control-plane security group."
  value       = aws_security_group.eks_cluster.id
}

output "node_security_group_id" {
  description = "ID of the EKS managed-node security group."
  value       = aws_security_group.eks_nodes.id
}
