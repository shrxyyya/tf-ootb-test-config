# ---------------------------------------------------------------------------
# modules/sqs/main.tf
#
# Security controls covered:
#   SQS.1 — sqs-queue-should-be-encrypted-at-rest
#   SQS.3 — sqs-queue-block-public-access
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Pass queue — encrypted, restricted policy
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "pass" {
  name                       = "regression-test-pass"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30
  kms_master_key_id          = var.kms_key_arn
  tags                       = var.tags
}

data "aws_iam_policy_document" "sqs_pass" {
  statement {
    sid       = "AllowOwnAccount"
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:ReceiveMessage"]
    resources = [aws_sqs_queue.pass.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_sqs_queue_policy" "pass" {
  queue_url = aws_sqs_queue.pass.id
  policy    = data.aws_iam_policy_document.sqs_pass.json
}

# ---------------------------------------------------------------------------
# SQS.1 fail — no KMS key (unencrypted at rest)
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                       = "regression-test-encrypted-fail"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30
  # No kms_master_key_id — intentional violation

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "SQS.1"
  })
}

# ---------------------------------------------------------------------------
# SQS.3 fail — public queue policy (Principal: *)
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                      = "regression-test-public-fail"
  message_retention_seconds = 86400
  kms_master_key_id         = var.kms_key_arn

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "SQS.3"
  })
}

data "aws_iam_policy_document" "sqs_public_fail" {
  statement {
    sid       = "AllowPublic"
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:ReceiveMessage"] # intentional violation: wildcard principal
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_sqs_queue_policy" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  queue_url = aws_sqs_queue.public_fail[0].id
  policy    = data.aws_iam_policy_document.sqs_public_fail.json
}
