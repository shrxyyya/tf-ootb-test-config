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

# ---------------------------------------------------------------------------
# Networking context — passed from root module; not used directly by IAM
# resources but accepted to keep the module interface consistent across all
# service modules.
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the shared VPC (unused by IAM resources; accepted for interface consistency)."
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (unused by IAM resources; accepted for interface consistency)."
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (unused by IAM resources; accepted for interface consistency)."
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "Availability zones (unused by IAM resources; accepted for interface consistency)."
  type        = list(string)
  default     = []
}
