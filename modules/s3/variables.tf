variable "create_failing_resources" {
  description = "When true (default), singleton account-level resources deploy in non-compliant configuration so detection policies fire. Set to false to verify policies produce no false positives against compliant configuration."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region for region-scoped resources."
  type        = string
  default     = "us-east-1"
}
