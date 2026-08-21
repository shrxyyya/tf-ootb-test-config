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
