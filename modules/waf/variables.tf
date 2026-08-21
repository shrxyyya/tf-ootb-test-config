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

variable "alb_arn" {
  description = "ARN of the ALB to associate with the WAFv2 Web ACL (optional; no association created if empty)."
  type        = string
  default     = ""
}

variable "logs_bucket_arn" {
  description = "ARN of the S3 bucket used as Firehose destination for WAF Classic logging."
  type        = string
}
