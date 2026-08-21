# ---------------------------------------------------------------------------
# modules/stepfunction/main.tf
#
# Security controls covered:
#   StepFunctions.1 — State machine execution logging enabled
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "sfn_trust" {
  statement {
    sid     = "SFNTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sfn_logs" {
  statement {
    sid    = "SFNCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutLogEvents",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "sfn" {
  name               = "regression-test-sfn"
  description        = "Execution role for regression test Step Functions state machines"
  assume_role_policy = data.aws_iam_policy_document.sfn_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "sfn_logs" {
  name   = "sfn-cloudwatch-logs-inline"
  role   = aws_iam_role.sfn.id
  policy = data.aws_iam_policy_document.sfn_logs.json
}

resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/states/regression-test"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Pass state machine — logging enabled at ERROR level
# ---------------------------------------------------------------------------

resource "aws_sfn_state_machine" "pass" {
  name     = "regression-test-pass"
  role_arn = aws_iam_role.sfn.arn

  definition = jsonencode({
    Comment = "Regression test state machine"
    StartAt = "PassState"
    States = {
      PassState = {
        Type = "Pass"
        End  = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tracing_configuration {
    enabled = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Fail: StepFunctions.1 — logging level = "OFF"
# ---------------------------------------------------------------------------

resource "aws_sfn_state_machine" "logging_fail" {
  count    = var.create_failing_resources ? 1 : 0
  name     = "regression-test-logging-fail"
  role_arn = aws_iam_role.sfn.arn

  definition = jsonencode({
    Comment = "Regression test - no logging"
    StartAt = "PassState"
    States = {
      PassState = {
        Type = "Pass"
        End  = true
      }
    }
  })

  logging_configuration {
    level = "OFF" # intentional violation
  }

  tracing_configuration {
    enabled = true
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "StepFunctions.1"
  })
}
