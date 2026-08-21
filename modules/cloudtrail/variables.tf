variable "create_failing_resources" {
  description = "When true (default), fail resources are created with intentional violations so detection policies fire. Set to false to verify policies produce no false positives."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the shared KMS CMK (from the KMS module) used to encrypt the trail and log group."
  type        = string
}

variable "log_bucket_id" {
  description = "S3 bucket ID for trail logs (from S3 module). Unused — this module provisions its own dedicated trail log bucket."
  type        = string
  default     = ""
}

variable "log_bucket_arn" {
  description = "S3 bucket ARN for trail logs (from S3 module). Unused — this module provisions its own dedicated trail log bucket."
  type        = string
  default     = ""
}

variable "cloudwatch_role_arn" {
  description = "ARN of the IAM role that allows CloudTrail to deliver logs to CloudWatch Logs (from the IAM module)."
  type        = string
}
