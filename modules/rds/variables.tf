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
  description = "Private subnet IDs. At least 3 required for Multi-AZ DB subnet group coverage."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones available in the target region."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for RDS storage encryption."
  type        = string
}

variable "rds_monitoring_role_arn" {
  description = "ARN of the IAM role used for RDS Enhanced Monitoring."
  type        = string
}

variable "db_password" {
  description = "Master password for RDS instances. Override in a tfvars file or via environment variable — never commit a real password."
  type        = string
  sensitive   = true
  default     = "Ch@ngeMe2024!"
}

variable "db_username" {
  description = "Master username for RDS instances. Deliberately not the engine default ('admin'/'postgres') to satisfy RDS.24/RDS.25."
  type        = string
  default     = "appuser"
}
