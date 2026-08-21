# ---------------------------------------------------------------------------
# modules/kinesis/main.tf
#
# Security controls covered:
#   Kinesis.1         — kinesis-stream-encrypted
#   Kinesis.3         — kinesis-stream-backup-retention-check
#   DataFirehose.1    — kinesis-firehose-delivery-stream-encrypted
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Pass Kinesis Data Stream — encrypted, 7-day retention
# ---------------------------------------------------------------------------

resource "aws_kinesis_stream" "pass" {
  name             = "regression-test-pass"
  shard_count      = 1
  retention_period = 168 # 7 days — satisfies kinesis-stream-backup-retention-check
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_arn
  tags             = var.tags
}

# ---------------------------------------------------------------------------
# Kinesis.1 fail — encryption_type = NONE
# ---------------------------------------------------------------------------

resource "aws_kinesis_stream" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  name             = "regression-test-encrypted-fail"
  shard_count      = 1
  retention_period = 168
  encryption_type  = "NONE" # intentional violation

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "Kinesis.1"
  })
}

# ---------------------------------------------------------------------------
# Kinesis.3 fail — retention_period = 24 h (minimum default, below threshold)
# ---------------------------------------------------------------------------

resource "aws_kinesis_stream" "retention_fail" {
  count = var.create_failing_resources ? 1 : 0

  name             = "regression-test-retention-fail"
  shard_count      = 1
  retention_period = 24 # intentional violation: below required retention
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_arn

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "Kinesis.3"
  })
}

# ---------------------------------------------------------------------------
# Firehose IAM role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "firehose_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "regression-test-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "firehose_policy" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [
      var.logs_bucket_arn,
      "${var.logs_bucket_arn}/*",
    ]
  }

  statement {
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "firehose" {
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_policy.json
}

# ---------------------------------------------------------------------------
# Pass Firehose delivery stream — SSE with CMK
# ---------------------------------------------------------------------------

resource "aws_kinesis_firehose_delivery_stream" "pass" {
  name        = "regression-test-pass"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = var.logs_bucket_arn
    prefix             = "firehose/"
    buffering_size     = 5
    buffering_interval = 300
    compression_format = "GZIP"
  }

  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = var.kms_key_arn
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# DataFirehose.1 fail — SSE disabled
# ---------------------------------------------------------------------------

resource "aws_kinesis_firehose_delivery_stream" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  name        = "regression-test-firehose-fail"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = var.logs_bucket_arn
    prefix             = "firehose-fail/"
    buffering_size     = 5
    buffering_interval = 300
    compression_format = "GZIP"
  }

  server_side_encryption {
    enabled = false # intentional violation
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "DataFirehose.1"
  })
}
