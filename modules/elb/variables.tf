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

variable "vpc_id" {
  description = "ID of the shared VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs. At least two required for multi-AZ ALB placement."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs."
  type        = list(string)
}

variable "logs_bucket_id" {
  description = "S3 bucket ID to receive ALB access logs (provided by the S3 module)."
  type        = string
}
