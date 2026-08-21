variable "create_failing_resources" {
  description = "When true (default), fail resources deploy with their intentional misconfiguration so detection policies fire. Set to false to verify policies produce no false positives against compliant configuration."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the shared VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS control-plane and node placement. Must contain at least 3 subnets spanning distinct AZs."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones corresponding to private_subnet_ids."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for EKS secrets encryption and CloudWatch log group encryption."
  type        = string
}

variable "eks_cluster_role_arn" {
  description = "ARN of the IAM role assumed by the EKS control plane. Sourced from the IAM module."
  type        = string
}

variable "eks_node_role_arn" {
  description = "ARN of the IAM role assumed by EKS managed node group instances. Sourced from the IAM module."
  type        = string
}
