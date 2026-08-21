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

variable "vpc_id" {
  description = "ID of the shared VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs. At least 2 required for the WorkSpaces Simple AD directory."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for WorkSpaces volume encryption."
  type        = string
}

variable "workspaces_bundle_id" {
  description = "WorkSpaces bundle ID to use for workspace instances. Defaults to Standard with Windows 10."
  type        = string
  default     = "wsb-bh8rsxt14"
}
