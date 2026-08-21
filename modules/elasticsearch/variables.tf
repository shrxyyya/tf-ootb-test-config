variable "create_failing_resources" {
  description = "When true (default), fail resources deploy with intentional violations so detection policies fire."
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
  description = "Private subnet IDs. At least 3 required for multi-AZ Elasticsearch deployment."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for Elasticsearch encryption at rest."
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets; used to scope the Elasticsearch security group ingress."
  type        = list(string)
  default     = []
}
