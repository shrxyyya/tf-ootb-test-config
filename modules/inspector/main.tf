# ---------------------------------------------------------------------------
# modules/inspector/main.tf
#
# Security controls covered:
#   Inspector2.1 — Amazon Inspector EC2 scanning should be enabled
#   Inspector2.2 — Amazon Inspector ECR scanning should be enabled
#   Inspector2.3 — Amazon Inspector Lambda standard scanning should be enabled
#   Inspector2.4 — Amazon Inspector Lambda code scanning should be enabled
#
# Singleton toggle: aws_inspector2_enabler is account-scoped.
#   create_failing_resources = true  → resource_types = [] (nothing enabled — intentional violation)
#   create_failing_resources = false → resource_types = ["EC2","ECR","LAMBDA","LAMBDA_CODE"] (pass)
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_inspector2_enabler" "main" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = var.create_failing_resources ? [] : ["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"]
}
