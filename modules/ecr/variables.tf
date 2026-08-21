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
