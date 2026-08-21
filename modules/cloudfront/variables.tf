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

variable "logs_bucket_id" {
  description = "ID (name) of the S3 bucket used for CloudFront access logging."
  type        = string
}

variable "wafv2_web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL to associate with the pass CloudFront distribution."
  type        = string
}
