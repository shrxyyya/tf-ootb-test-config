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

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt SQS queues."
  type        = string
}
