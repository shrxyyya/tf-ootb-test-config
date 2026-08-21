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
# Shared IAM role for DataSync → S3
# ---------------------------------------------------------------------------

resource "aws_iam_role" "datasync" {
  name = "regression-test-datasync"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "datasync.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "regression-test-datasync" })
}

resource "aws_iam_role_policy" "datasync_s3" {
  name = "regression-test-datasync-s3"
  role = aws_iam_role.datasync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:GetObjectTagging",
        "s3:PutObjectTagging",
      ]
      Resource = [
        var.logs_bucket_arn,
        "${var.logs_bucket_arn}/*",
      ]
    }]
  })
}

# ---------------------------------------------------------------------------
# DataSync S3 location (used as both source and destination for test)
# ---------------------------------------------------------------------------

resource "aws_datasync_location_s3" "source" {
  s3_bucket_arn = var.logs_bucket_arn
  subdirectory  = "/datasync-source/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync.arn
  }

  tags = merge(var.tags, { Name = "regression-test-datasync-source" })
}

resource "aws_cloudwatch_log_group" "datasync" {
  name              = "/aws/datasync/regression-test"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "regression-test-datasync" })
}

# ---------------------------------------------------------------------------
# DataSync.1 — datasync-task-should-have-logging-enabled
# Pass: cloudwatch_log_group_arn set, log_level = TRANSFER
# ---------------------------------------------------------------------------

resource "aws_datasync_task" "pass" {
  source_location_arn      = aws_datasync_location_s3.source.arn
  destination_location_arn = aws_datasync_location_s3.source.arn
  cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.datasync.arn}:*"

  options {
    log_level              = "TRANSFER"
    verify_mode            = "ONLY_FILES_TRANSFERRED"
    transfer_mode          = "CHANGED"
    posix_permissions      = "NONE"
    preserve_deleted_files = "REMOVE"
    uid                    = "NONE"
    gid                    = "NONE"
    overwrite_mode         = "ALWAYS"
    atime                  = "BEST_EFFORT"
    mtime                  = "PRESERVE"
    bytes_per_second       = -1
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# DataSync.1 — fail: log_level = OFF, no cloudwatch_log_group_arn
# ---------------------------------------------------------------------------

resource "aws_datasync_task" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  source_location_arn      = aws_datasync_location_s3.source.arn
  destination_location_arn = aws_datasync_location_s3.source.arn
  # cloudwatch_log_group_arn intentionally omitted — intentional violation

  options {
    log_level              = "OFF" # intentional violation
    verify_mode            = "ONLY_FILES_TRANSFERRED"
    transfer_mode          = "CHANGED"
    posix_permissions      = "NONE"
    preserve_deleted_files = "REMOVE"
    uid                    = "NONE"
    gid                    = "NONE"
    overwrite_mode         = "ALWAYS"
    atime                  = "BEST_EFFORT"
    mtime                  = "PRESERVE"
    bytes_per_second       = -1
  }

  tags = merge(var.tags, {
    Name            = "regression-test-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "DataSync.1"
  })
}
