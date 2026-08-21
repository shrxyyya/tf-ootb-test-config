# ---------------------------------------------------------------------------
# modules/eventbridge/main.tf
#
# Security controls covered:
#   EventBridge.3 — Custom event bus should have a resource-based policy attached
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "event_bus" {
  statement {
    sid       = "AllowAccountPutEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.pass.arn]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# ---------------------------------------------------------------------------
# Pass event bus — has a resource-based policy attached
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_bus" "pass" {
  name = "regression-test-pass"
  tags = var.tags
}

resource "aws_cloudwatch_event_bus_policy" "pass" {
  event_bus_name = aws_cloudwatch_event_bus.pass.name
  policy         = data.aws_iam_policy_document.event_bus.json
}

# ---------------------------------------------------------------------------
# Fail: EventBridge.3 — custom event bus with no resource-based policy
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_bus" "no_policy_fail" {
  count = var.create_failing_resources ? 1 : 0
  name  = "regression-test-no-policy-fail"
  # intentional violation: no aws_cloudwatch_event_bus_policy attached
  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EventBridge.3"
  })
}
