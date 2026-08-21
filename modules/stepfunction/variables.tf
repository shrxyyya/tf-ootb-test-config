variable "create_failing_resources" {
  description = "When true (default), fail resources deploy with one intentional misconfiguration so detection policies fire. Set to false to verify policies produce no false positives against compliant configuration."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the Step Functions CloudWatch log group."
  type        = string
}
