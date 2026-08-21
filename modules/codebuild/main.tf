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
# Shared IAM role for CodeBuild
# ---------------------------------------------------------------------------

resource "aws_iam_role" "codebuild" {
  name = "regression-test-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "regression-test-codebuild" })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "regression-test-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
        ]
        Resource = "${var.logs_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = var.kms_key_arn
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/regression-test"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, { Name = "regression-test-codebuild" })
}

# ---------------------------------------------------------------------------
# CodeBuild.4 + CodeBuild.3 — pass: CW + S3 logging both enabled + encrypted
# ---------------------------------------------------------------------------

resource "aws_codebuild_project" "pass" {
  name         = "regression-test-pass"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "NO_SOURCE"
    buildspec = "version: 0.2\nphases:\n  build:\n    commands:\n      - echo regression-test-pass"
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.codebuild.name
    }

    s3_logs {
      status              = "ENABLED"
      location            = "${var.logs_bucket_id}/codebuild/"
      encryption_disabled = false
    }
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# CodeBuild.4 — fail: both CloudWatch and S3 logging disabled
# ---------------------------------------------------------------------------

resource "aws_codebuild_project" "no_logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  name         = "regression-test-no-logging-fail"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "NO_SOURCE"
    buildspec = "version: 0.2\nphases:\n  build:\n    commands:\n      - echo regression-test-no-logging-fail"
  }

  logs_config {
    cloudwatch_logs {
      status = "DISABLED" # intentional violation
    }

    s3_logs {
      status = "DISABLED" # intentional violation
    }
  }

  tags = merge(var.tags, {
    Name            = "regression-test-no-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "CodeBuild.4"
  })
}

# ---------------------------------------------------------------------------
# CodeBuild.3 — fail: S3 logs with encryption_disabled = true
# ---------------------------------------------------------------------------

resource "aws_codebuild_project" "s3_unencrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  name         = "regression-test-s3-unenc-fail"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "NO_SOURCE"
    buildspec = "version: 0.2\nphases:\n  build:\n    commands:\n      - echo regression-test-s3-unenc-fail"
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.codebuild.name
    }

    s3_logs {
      status              = "ENABLED"
      location            = "${var.logs_bucket_id}/codebuild-fail/"
      encryption_disabled = true # intentional violation
    }
  }

  tags = merge(var.tags, {
    Name            = "regression-test-s3-unenc-fail"
    compliance_test = "intentional_violation"
    controls        = "CodeBuild.3"
  })
}

# ---------------------------------------------------------------------------
# CodeBuild.1 — fail: Bitbucket source URL containing credentials
# ---------------------------------------------------------------------------

resource "aws_codebuild_project" "bitbucket_creds_fail" {
  count = var.create_failing_resources ? 1 : 0

  name         = "regression-test-bitbucket-creds-fail"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type     = "BITBUCKET"
    location = "https://user:password@bitbucket.org/example/regression-test.git" # intentional violation — credentials in URL
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }

  tags = merge(var.tags, {
    Name            = "regression-test-bitbucket-creds-fail"
    compliance_test = "intentional_violation"
    controls        = "CodeBuild.1"
  })
}
