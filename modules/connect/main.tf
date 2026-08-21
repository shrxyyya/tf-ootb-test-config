terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Connect.2 — connect-instance-flow-logging-should-be-enabled
# Pass: contact_flow_logs_enabled = true
# ---------------------------------------------------------------------------

resource "aws_connect_instance" "pass" {
  identity_management_type         = "CONNECT_MANAGED"
  inbound_calls_enabled            = true
  outbound_calls_enabled           = true
  contact_flow_logs_enabled        = true
  auto_resolve_best_voices_enabled = true
  contact_lens_enabled             = true
  early_media_enabled              = true
  multi_party_conference_enabled   = false

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# Connect.2 — fail: contact_flow_logs_enabled = false
# ---------------------------------------------------------------------------

resource "aws_connect_instance" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  identity_management_type         = "CONNECT_MANAGED"
  inbound_calls_enabled            = true
  outbound_calls_enabled           = true
  contact_flow_logs_enabled        = false # intentional violation
  auto_resolve_best_voices_enabled = true
  contact_lens_enabled             = true
  early_media_enabled              = true
  multi_party_conference_enabled   = false

  tags = merge(var.tags, {
    Name            = "regression-test-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "Connect.2"
  })
}
