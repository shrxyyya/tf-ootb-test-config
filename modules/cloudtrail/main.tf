# ---------------------------------------------------------------------------
# modules/cloudtrail/main.tf
#
# Security controls covered:
#   CloudTrail.2 / CIS-3.5  — cloudtrail-server-side-encryption-enabled
#   CloudTrail.4 / CIS-3.2  — cloudtrail-log-file-validation-enabled
#   CloudTrail.5 / CIS-3.1  — cloudtrail-cloudwatch-logs-group-arn-present / multi-region
#   CIS-3.4                 — S3 access logging on CloudTrail bucket
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
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# CloudTrail S3 bucket (dedicated — one canonical bucket for all trails)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "trail_logs" {
  bucket        = "cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(var.tags, {
    Name    = "cloudtrail-logs"
    Purpose = "cloudtrail-log-storage"
  })
}

resource "aws_s3_bucket_public_access_block" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id

  depends_on = [aws_s3_bucket_versioning.trail_logs]

  rule {
    id     = "audit-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      # 7 years — realistic audit log retention
      days = 2555
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# CloudTrail requires specific bucket policy statements to allow log delivery
data "aws_iam_policy_document" "trail_logs_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail_logs.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/regression-test-pass"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  policy = data.aws_iam_policy_document.trail_logs_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.trail_logs]
}

# ---------------------------------------------------------------------------
# CIS-3.4 — S3 access logging on the CloudTrail bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "trail_access_logs" {
  bucket        = "cloudtrail-access-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(var.tags, {
    Name    = "cloudtrail-access-logs"
    Purpose = "cloudtrail-bucket-access-logging"
  })
}

resource "aws_s3_bucket_public_access_block" "trail_access_logs" {
  bucket = aws_s3_bucket.trail_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "trail_access_logs" {
  bucket = aws_s3_bucket.trail_access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail_access_logs" {
  bucket = aws_s3_bucket.trail_access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# pass: access logging enabled on the trail log bucket (satisfies CIS-3.4)
resource "aws_s3_bucket_logging" "trail_logs_pass" {
  bucket        = aws_s3_bucket.trail_logs.id
  target_bucket = aws_s3_bucket.trail_access_logs.id
  target_prefix = "cloudtrail-bucket/"

  depends_on = [aws_s3_bucket_ownership_controls.trail_access_logs]
}

# ---------------------------------------------------------------------------
# CloudWatch log group for trail delivery
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/regression-test"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "cloudtrail-regression-test"
  })
}

# ---------------------------------------------------------------------------
# CloudTrail.2 / CIS-3.5 — cloudtrail-server-side-encryption-enabled
# ---------------------------------------------------------------------------

# pass: KMS encryption + log file validation + multi-region + CloudWatch delivery
resource "aws_cloudtrail" "pass" {
  name                          = "regression-test-pass"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  kms_key_id                    = var.kms_key_arn
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = var.cloudwatch_role_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })

  depends_on = [aws_s3_bucket_policy.trail_logs]
}

# fail: no KMS encryption
# intentional_violation: kms_key_id omitted
resource "aws_cloudtrail" "fail" {
  count = var.create_failing_resources ? 1 : 0

  name                          = "regression-test-encryption-fail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  s3_key_prefix                 = "encryption-fail"
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = var.cloudwatch_role_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(var.tags, {
    Name            = "regression-test-encryption-fail"
    compliance_test = "intentional_violation"
    controls        = "CloudTrail.2,CIS-3.5"
  })

  depends_on = [aws_s3_bucket_policy.trail_logs]
}

# ---------------------------------------------------------------------------
# CloudTrail.4 / CIS-3.2 — cloudtrail-log-file-validation-enabled
# ---------------------------------------------------------------------------

# fail: log file validation disabled
# intentional_violation: enable_log_file_validation = false
resource "aws_cloudtrail" "validation_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                          = "regression-test-validation-fail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  s3_key_prefix                 = "validation-fail"
  is_multi_region_trail         = false
  enable_log_file_validation    = false
  include_global_service_events = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(var.tags, {
    Name            = "regression-test-validation-fail"
    compliance_test = "intentional_violation"
    controls        = "CloudTrail.4,CIS-3.2"
  })

  depends_on = [aws_s3_bucket_policy.trail_logs]
}

# ---------------------------------------------------------------------------
# CloudTrail.5 / CIS-3.1 — cloudtrail-cloudwatch-logs-group-arn-present
#                          multi-region trail required
# ---------------------------------------------------------------------------

# fail: no CloudWatch log group + single-region
# intentional_violation: cloud_watch_logs_group_arn omitted, is_multi_region_trail = false
resource "aws_cloudtrail" "cw_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                          = "regression-test-cw-fail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  s3_key_prefix                 = "cw-fail"
  kms_key_id                    = var.kms_key_arn
  is_multi_region_trail         = false
  enable_log_file_validation    = true
  include_global_service_events = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(var.tags, {
    Name            = "regression-test-cw-fail"
    compliance_test = "intentional_violation"
    controls        = "CloudTrail.5,CIS-3.1"
  })

  depends_on = [aws_s3_bucket_policy.trail_logs]
}
