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

variable "kms_key_arn" {
  description = "ARN of the KMS key used for CodeBuild artifact encryption."
  type        = string
}

variable "logs_bucket_id" {
  description = "ID (name) of the S3 bucket used for CodeBuild S3 logs."
  type        = string
}

variable "logs_bucket_arn" {
  description = "ARN of the S3 bucket used for CodeBuild S3 logs."
  type        = string
}
