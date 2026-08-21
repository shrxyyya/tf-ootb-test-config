variable "create_failing_resources" {
  description = "When true (default), fail resources deploy with intentional violations so detection policies fire. Set to false to verify policies produce no false positives against compliant configuration."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for DynamoDB table and DAX cluster encryption."
  type        = string
}

variable "vpc_id" {
  description = "ID of the shared VPC (used for DAX security group)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used for the DAX subnet group."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets; used to scope the DAX security group ingress."
  type        = list(string)
  default     = []
}
