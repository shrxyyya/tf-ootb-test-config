terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Athena.4 — athena-workgroup-should-have-logging-enabled
# Pass: result output location + CloudWatch metrics enabled.
# ---------------------------------------------------------------------------

resource "aws_athena_workgroup" "pass" {
  name = "regression-test-pass"

  configuration {
    result_configuration {
      output_location = "s3://${var.logs_bucket_id}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.kms_key_arn
      }
    }

    publish_cloudwatch_metrics_enabled = true
    enforce_workgroup_configuration    = true
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# Athena.4 — fail: no output_location + metrics disabled
# ---------------------------------------------------------------------------

resource "aws_athena_workgroup" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "regression-test-logging-fail"

  configuration {
    # output_location intentionally omitted — intentional violation
    publish_cloudwatch_metrics_enabled = false # intentional violation
  }

  tags = merge(var.tags, {
    Name            = "regression-test-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "Athena.4"
  })
}
