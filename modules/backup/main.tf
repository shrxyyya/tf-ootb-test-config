# ---------------------------------------------------------------------------
# modules/backup/main.tf
#
# Security controls covered:
#   Backup.1 — Backup vault recovery points should be encrypted at rest
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Pass backup vault — encrypted with customer-managed KMS key
# ---------------------------------------------------------------------------

resource "aws_backup_vault" "pass" {
  name        = "regression-test-pass"
  kms_key_arn = var.kms_key_arn
  tags        = var.tags
}

resource "aws_backup_plan" "pass" {
  name = "regression-test-pass"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.pass.name
    schedule          = "cron(0 3 * * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 30
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Fail: Backup.1 — vault uses default AWS-managed key (no customer KMS key)
# ---------------------------------------------------------------------------

resource "aws_backup_vault" "unencrypted_fail" {
  count = var.create_failing_resources ? 1 : 0
  name  = "regression-test-unencrypted-fail"
  # intentional violation: no kms_key_arn — uses default AWS-managed key
  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "Backup.1"
  })
}
