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
  description = "VPC ID used for the Lambda security group."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs across multiple AZs for Lambda VPC config (Lambda.5)."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt Lambda environment variables and the CloudWatch log group."
  type        = string
}

variable "lambda_execution_role_arn" {
  description = "IAM role ARN granted to Lambda functions as their execution role."
  type        = string
}
