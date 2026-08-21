# ---------------------------------------------------------------------------
# modules/macie/main.tf
#
# Security controls covered:
#   Macie.1 — Macie should be enabled
#
# Singleton toggle: only one aws_macie2_account can exist per account.
#   create_failing_resources = true  → status = "PAUSED"  (intentional violation)
#   create_failing_resources = false → status = "ENABLED" (pass)
# ---------------------------------------------------------------------------

resource "aws_macie2_account" "main" {
  status                       = var.create_failing_resources ? "PAUSED" : "ENABLED"
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}
