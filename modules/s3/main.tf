terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# S3.8 / s3-block-public-access-account-level  (SINGLETON — toggle-driven)
#
# create_failing_resources = true  → all four flags false  (intentional violation)
# create_failing_resources = false → all four flags true   (compliant)
# ---------------------------------------------------------------------------

resource "aws_s3_account_public_access_block" "main" {
  block_public_acls       = var.create_failing_resources ? false : true
  block_public_policy     = var.create_failing_resources ? false : true
  ignore_public_acls      = var.create_failing_resources ? false : true
  restrict_public_buckets = var.create_failing_resources ? false : true
}

# ---------------------------------------------------------------------------
# Dedicated access-logging bucket  (S3.9 target)
#
# No pass/fail variant — this is infrastructure supporting other controls.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  bucket = "access-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name    = "access-logs"
    Purpose = "s3-server-access-logging"
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ---------------------------------------------------------------------------
# S3.1 / S3.2 / S3.3 / CIS-2.1.4 — Bucket-level public access block
# S3.5 / CIS-2.1.1                — Require SSL (bucket policy)
# S3.9                            — Server access logging
# S3.13                           — Lifecycle policy
# CIS-2.1.2                       — MFA delete
#
# pass  → app_data_pass  (always created)
# fail  → app_data_fail  (count-gated)
# ---------------------------------------------------------------------------

# --- Pass bucket -----------------------------------------------------------

resource "aws_s3_bucket" "app_data_pass" {
  bucket = "app-data-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "app-data-pass"
  })
}

resource "aws_s3_bucket_public_access_block" "app_data_pass" {
  bucket = aws_s3_bucket.app_data_pass.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CIS-2.1.2 — versioning with MFA delete
# ponytail: mfa_delete=Enabled requires root credentials; set to Disabled for
# Terraform-manageable apply, policy tests the attribute value.
resource "aws_s3_bucket_versioning" "pass" {
  bucket = aws_s3_bucket.app_data_pass.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

# S3.13 — Lifecycle policy (versioning must exist first)
resource "aws_s3_bucket_lifecycle_configuration" "pass" {
  bucket = aws_s3_bucket.app_data_pass.id

  depends_on = [aws_s3_bucket_versioning.pass]

  rule {
    id     = "transition-and-expire"
    status = "Enabled"
    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# S3.9 — Server access logging
resource "aws_s3_bucket_logging" "pass" {
  bucket        = aws_s3_bucket.app_data_pass.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "app-data/"
}

# S3.5 / CIS-2.1.1 — Deny non-SSL requests
data "aws_iam_policy_document" "ssl_pass" {
  statement {
    sid     = "DenyNonSSL"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.app_data_pass.arn,
      "${aws_s3_bucket.app_data_pass.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "ssl_pass" {
  bucket = aws_s3_bucket.app_data_pass.id
  policy = data.aws_iam_policy_document.ssl_pass.json

  depends_on = [aws_s3_bucket_public_access_block.app_data_pass]
}

# --- Fail bucket -----------------------------------------------------------
# Intentional violations:
#   public_access_block → all four flags false  (S3.1, S3.2, S3.3, CIS-2.1.4)
#   bucket policy       → no SSL condition       (S3.5, CIS-2.1.1)
#   no logging resource                          (S3.9)
#   no lifecycle config                          (S3.13)
#   mfa_delete = Disabled                        (CIS-2.1.2)

resource "aws_s3_bucket" "app_data_fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = "app-data-fail-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name            = "app-data-fail"
    compliance_test = "intentional_violation"
    controls        = "S3.1,S3.2,S3.3,S3.5,S3.9,S3.13,CIS-2.1.1,CIS-2.1.2,CIS-2.1.4"
  })
}

# S3.1 / S3.2 / S3.3 / CIS-2.1.4 — intentional violation: all four flags false
resource "aws_s3_bucket_public_access_block" "app_data_fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = aws_s3_bucket.app_data_fail[0].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# CIS-2.1.2 — intentional violation: mfa_delete = Disabled
resource "aws_s3_bucket_versioning" "fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = aws_s3_bucket.app_data_fail[0].id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

# S3.5 / CIS-2.1.1 — intentional violation: policy allows all without SSL condition
data "aws_iam_policy_document" "ssl_fail" {
  statement {
    sid     = "AllowAllNoSSLCheck"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = var.create_failing_resources ? [
      aws_s3_bucket.app_data_fail[0].arn,
      "${aws_s3_bucket.app_data_fail[0].arn}/*",
    ] : ["arn:aws:s3:::placeholder"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "ssl_fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = aws_s3_bucket.app_data_fail[0].id
  policy = data.aws_iam_policy_document.ssl_fail.json

  depends_on = [aws_s3_bucket_public_access_block.app_data_fail]
}

# ---------------------------------------------------------------------------
# S3.6 — s3-bucket-policy-restrict-access-to-other-accounts
#
# pass  → policy requires aws:PrincipalAccount matches own account
# fail  → policy allows Principal:"*" with no account condition
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "cross_account_pass" {
  bucket = "cross-account-pass-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "cross-account-pass"
  })
}

resource "aws_s3_bucket_public_access_block" "cross_account_pass" {
  bucket = aws_s3_bucket.cross_account_pass.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "cross_account_pass" {
  statement {
    sid     = "RestrictToOwnAccount"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.cross_account_pass.arn,
      "${aws_s3_bucket.cross_account_pass.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "cross_account_pass" {
  bucket = aws_s3_bucket.cross_account_pass.id
  policy = data.aws_iam_policy_document.cross_account_pass.json

  depends_on = [aws_s3_bucket_public_access_block.cross_account_pass]
}

resource "aws_s3_bucket" "cross_account_fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = "cross-account-fail-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name            = "cross-account-fail"
    compliance_test = "intentional_violation"
    controls        = "S3.6"
  })
}

resource "aws_s3_bucket_public_access_block" "cross_account_fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = aws_s3_bucket.cross_account_fail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3.6 — intentional violation: Principal:"*" with no aws:PrincipalAccount condition
data "aws_iam_policy_document" "cross_account_fail" {
  statement {
    sid     = "AllowAnyAccount"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = var.create_failing_resources ? [
      "${aws_s3_bucket.cross_account_fail[0].arn}/*",
    ] : ["arn:aws:s3:::placeholder/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "cross_account_fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = aws_s3_bucket.cross_account_fail[0].id
  policy = data.aws_iam_policy_document.cross_account_fail.json

  depends_on = [aws_s3_bucket_public_access_block.cross_account_fail]
}

# ---------------------------------------------------------------------------
# S3.19 — s3-access-point-block-public-access-enabled
#
# pass  → access point on app_data_pass, all public-access-block flags true
# fail  → access point on app_data_fail, all flags false
# ---------------------------------------------------------------------------

resource "aws_s3_access_point" "pass" {
  bucket = aws_s3_bucket.app_data_pass.id
  name   = "app-data-pass-ap"

  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

resource "aws_s3_access_point" "fail" {
  count = var.create_failing_resources ? 1 : 0

  bucket = aws_s3_bucket.app_data_fail[0].id
  name   = "app-data-fail-ap"

  # S3.19 — intentional violation: all public-access-block flags false
  public_access_block_configuration {
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
  }
}
