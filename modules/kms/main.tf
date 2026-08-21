# ---------------------------------------------------------------------------
# modules/kms/main.tf
#
# Security controls covered:
#   KMS.1  — kms-restrict-iam-inline-policies-decrypt-all-kms-keys
#   KMS.2  — kms-restrict-iam-inline-policies-decrypt-all-kms-keys
#   KMS.3  — KMS key rotation enabled (rotation_period_in_days)
#   CIS-3.6 — CMK rotation enabled
#
# Shared KMS key (aws_kms_key.shared) is always compliant and used by
# other service modules that need a customer-managed key.
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
# Key policy — grants account root full KMS access (required for usability)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "key_policy" {
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# ---------------------------------------------------------------------------
# KMS.3 / CIS-3.6 — Key rotation enabled
# ---------------------------------------------------------------------------

# pass: rotation enabled with 90-day period
resource "aws_kms_key" "pass" {
  description             = "CMK for regression test suite - compliant"
  enable_key_rotation     = true
  rotation_period_in_days = 90
  deletion_window_in_days = 30
  multi_region            = false
  policy                  = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

resource "aws_kms_alias" "pass" {
  name          = "alias/regression-test-pass"
  target_key_id = aws_kms_key.pass.key_id
}

# fail: rotation disabled
# intentional_violation: enable_key_rotation = false
resource "aws_kms_key" "fail" {
  count = var.create_failing_resources ? 1 : 0

  description             = "CMK for regression test suite - intentional KMS.3 violation"
  enable_key_rotation     = false
  deletion_window_in_days = 30
  multi_region            = false
  policy                  = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name            = "regression-test-fail"
    compliance_test = "intentional_violation"
    controls        = "KMS.3,CIS-3.6"
  })
}

resource "aws_kms_alias" "fail" {
  count = var.create_failing_resources ? 1 : 0

  name          = "alias/regression-test-fail"
  target_key_id = aws_kms_key.fail[0].key_id
}

# ---------------------------------------------------------------------------
# Shared CMK — always compliant; consumed by other service modules
# ---------------------------------------------------------------------------

resource "aws_kms_key" "shared" {
  description             = "Shared CMK for test suite resources"
  enable_key_rotation     = true
  rotation_period_in_days = 90
  deletion_window_in_days = 30
  multi_region            = false
  policy                  = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name = "regression-test-shared"
  })
}

resource "aws_kms_alias" "shared" {
  name          = "alias/regression-test-shared"
  target_key_id = aws_kms_key.shared.key_id
}

# ---------------------------------------------------------------------------
# KMS.1 / KMS.2 — kms-restrict-iam-inline-policies-decrypt-all-kms-keys
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "kms_user_trust" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# pass: kms:Decrypt scoped to the shared key ARN only
data "aws_iam_policy_document" "kms_decrypt_scoped" {
  statement {
    sid       = "DecryptSpecificKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.shared.arn]
  }
}

resource "aws_iam_role" "kms_user_pass" {
  name               = "kms-user-pass"
  description        = "Role with kms:Decrypt scoped to a specific key - compliant with KMS.1/KMS.2"
  assume_role_policy = data.aws_iam_policy_document.kms_user_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy" "kms_user_pass" {
  name   = "kms-decrypt-scoped"
  role   = aws_iam_role.kms_user_pass.id
  policy = data.aws_iam_policy_document.kms_decrypt_scoped.json
}

# fail: kms:Decrypt on Resource = "*"
# intentional_violation: resources = ["*"] grants decrypt on all KMS keys
data "aws_iam_policy_document" "kms_decrypt_wildcard" {
  statement {
    sid       = "DecryptAllKeys"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "kms_user_fail" {
  count = var.create_failing_resources ? 1 : 0

  name               = "kms-user-fail"
  description        = "Role with kms:Decrypt on * - intentional KMS.1/KMS.2 violation"
  assume_role_policy = data.aws_iam_policy_document.kms_user_trust.json
  path               = "/"

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "KMS.1,KMS.2"
  })
}

resource "aws_iam_role_policy" "kms_user_fail" {
  count = var.create_failing_resources ? 1 : 0

  name   = "kms-decrypt-wildcard"
  role   = aws_iam_role.kms_user_fail[0].id
  policy = data.aws_iam_policy_document.kms_decrypt_wildcard.json
}
