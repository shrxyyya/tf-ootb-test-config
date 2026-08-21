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
  description = "Private subnet IDs (at least two for multi-AZ ASG placement)."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones corresponding to the private subnets."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for EBS volume encryption."
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to attach to the pass ASG (provided by ELB module)."
  type        = string
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile to attach to instances."
  type        = string
}
