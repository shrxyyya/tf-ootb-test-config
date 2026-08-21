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

variable "wafv2_web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL to associate with the pass API Gateway stage (provided by the WAF module)."
  type        = string
}
