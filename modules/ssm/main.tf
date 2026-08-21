# ---------------------------------------------------------------------------
# modules/ssm/main.tf
#
# Security controls covered:
#   SSM.4 — SSM documents should not be public
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Pass SSM document — private (no public sharing)
# ---------------------------------------------------------------------------

resource "aws_ssm_document" "pass" {
  name            = "regression-test-pass"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Regression test SSM document"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "runScript"
        inputs = {
          runCommand = ["echo hello"]
        }
      }
    ]
  })

  permissions = {
    type        = "Share"
    account_ids = "" # private — no sharing
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Fail: SSM.4 — document shared publicly (account_ids = "All")
# ---------------------------------------------------------------------------

resource "aws_ssm_document" "public_fail" {
  count           = var.create_failing_resources ? 1 : 0
  name            = "regression-test-public-fail"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Regression test SSM document - public"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "runScript"
        inputs = {
          runCommand = ["echo hello"]
        }
      }
    ]
  })

  permissions = {
    type        = "Share"
    account_ids = "All" # intentional violation — makes document public
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "SSM.4"
  })
}
