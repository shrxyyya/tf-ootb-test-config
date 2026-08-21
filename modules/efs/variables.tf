variable "create_failing_resources" {
  description = "When true (default), fail resources are created with intentional violations."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for the EFS security group."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EFS mount targets."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt EFS file systems."
  type        = string
}
