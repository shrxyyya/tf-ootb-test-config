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

variable "private_subnet_ids" {
  description = "Private subnet IDs for Elastic Beanstalk environment placement."
  type        = list(string)
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile to attach to Beanstalk instances."
  type        = string
}
