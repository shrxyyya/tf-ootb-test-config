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
  description = "ARN of the KMS key used to encrypt Kinesis streams and Firehose."
  type        = string
}

variable "logs_bucket_id" {
  description = "ID (name) of the S3 bucket used as Firehose destination."
  type        = string
}

variable "logs_bucket_arn" {
  description = "ARN of the S3 bucket used as Firehose destination."
  type        = string
}
