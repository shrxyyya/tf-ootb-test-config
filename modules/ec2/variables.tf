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

variable "vpc_id" {
  description = "ID of the shared VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs. Index 0 is used for EC2 instance placement."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones. Index 0 is used for AZ-scoped resources."
  type        = list(string)
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile to attach to EC2 instances."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for EBS volume encryption."
  type        = string
}
