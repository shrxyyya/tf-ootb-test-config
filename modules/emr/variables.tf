variable "create_failing_resources" {
  description = "When true (default), singleton resources deploy in non-compliant configuration. Set to false to deploy in compliant configuration."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for EMR encryption at rest."
  type        = string
}

variable "logs_bucket_id" {
  description = "ID (name) of the S3 bucket used for EMR TLS certificate storage."
  type        = string
}
