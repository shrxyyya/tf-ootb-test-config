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
# Shared IAM role for Glue
# ---------------------------------------------------------------------------

resource "aws_iam_role" "glue" {
  name = "regression-test-glue"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "regression-test-glue" })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_s3" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ---------------------------------------------------------------------------
# Glue.4 — glue-spark-job-supported-version
# Pass: glue_version = "4.0" (current supported)
# ---------------------------------------------------------------------------

resource "aws_glue_job" "pass" {
  name         = "regression-test-pass"
  role_arn     = aws_iam_role.glue.arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.logs_bucket_id}/glue-scripts/etl.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
  }

  number_of_workers = 2
  worker_type       = "G.1X"
  timeout           = 60

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# Glue.4 — fail: glue_version = "2.0" (EOL / unsupported version)
# ---------------------------------------------------------------------------

resource "aws_glue_job" "version_fail" {
  count = var.create_failing_resources ? 1 : 0

  name         = "regression-test-version-fail"
  role_arn     = aws_iam_role.glue.arn
  glue_version = "2.0" # intentional violation — EOL version

  command {
    name            = "glueetl"
    script_location = "s3://${var.logs_bucket_id}/glue-scripts/etl-fail.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"
  }

  number_of_workers = 2
  worker_type       = "G.1X"
  timeout           = 60

  tags = merge(var.tags, {
    Name            = "regression-test-version-fail"
    compliance_test = "intentional_violation"
    controls        = "Glue.4"
  })
}
