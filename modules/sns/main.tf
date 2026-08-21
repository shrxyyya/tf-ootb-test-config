# ---------------------------------------------------------------------------
# modules/sns/main.tf
#
# Security controls covered:
#   SNS.4 — sns-topic-access-policies-should-not-allow-public-access
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
# Pass topic — policy restricted to own account
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "pass" {
  name              = "regression-test-pass"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "sns_pass" {
  statement {
    sid       = "AllowOwnAccount"
    effect    = "Allow"
    actions   = ["SNS:Publish", "SNS:Subscribe"]
    resources = [aws_sns_topic.pass.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_sns_topic_policy" "pass" {
  arn    = aws_sns_topic.pass.arn
  policy = data.aws_iam_policy_document.sns_pass.json
}

# ---------------------------------------------------------------------------
# SNS.4 fail — policy allows public access (Principal: *)
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  name              = "regression-test-public-fail"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "SNS.4"
  })
}

data "aws_iam_policy_document" "sns_public_fail" {
  statement {
    sid       = "AllowPublic"
    effect    = "Allow"
    actions   = ["SNS:Publish"] # intentional violation: wildcard principal
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_sns_topic_policy" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  arn    = aws_sns_topic.public_fail[0].arn
  policy = data.aws_iam_policy_document.sns_public_fail.json
}
