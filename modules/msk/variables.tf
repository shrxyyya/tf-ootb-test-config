variable "create_failing_resources" {
  description = "When true (default), fail resources deploy with intentional violations so detection policies fire. Set to false to verify policies produce no false positives against compliant configuration."
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
  description = "Private subnet IDs. Exactly 3 required (one per broker node)."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key (reserved for future MSK at-rest encryption; not currently used by the MSK provider)."
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets; used to scope the MSK security group ingress."
  type        = list(string)
  default     = []
}

# MSK Connect is expensive and requires a running cluster + S3 plugin artifact.
# Defaulting to false avoids always-on cost in regression environments.
variable "create_msk_connect" {
  description = "When true, creates MSK Connect connector resources for the MSK.2 control test. Defaults to false to avoid provisioning costs; enable only in dedicated MSK Connect test runs."
  type        = bool
  default     = false
}

variable "msk_connect_worker_role_arn" {
  description = "ARN of the IAM role used by MSK Connect connectors. Only required when create_msk_connect = true."
  type        = string
  default     = ""
}
