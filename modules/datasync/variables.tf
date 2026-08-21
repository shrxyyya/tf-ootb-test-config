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

variable "logs_bucket_arn" {
  description = "ARN of the S3 bucket used as a DataSync source/destination location."
  type        = string
}
