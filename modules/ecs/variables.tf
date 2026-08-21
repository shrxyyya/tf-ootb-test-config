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
  description = "Private subnet IDs used for Fargate task network placement."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for CloudWatch log group encryption."
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the IAM role assumed by the ECS task execution agent (from IAM module)."
  type        = string
}

variable "app_security_group_id" {
  description = "ID of the application security group to attach to Fargate tasks (from EC2 module)."
  type        = string
}
