# ---------------------------------------------------------------------------
# modules/secretsmanager/main.tf
#
# Security controls covered:
#   SecretsManager.1 — secretsmanager-auto-rotation-enabled-check
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Rotation Lambda — minimal inline rotator
# ---------------------------------------------------------------------------

data "archive_file" "rotator_zip" {
  type        = "zip"
  output_path = "${path.module}/rotator.zip"

  source {
    filename = "index.py"
    content  = <<-EOF
      import boto3, os

      def handler(event, context):
          """Minimal Secrets Manager rotation stub."""
          secret_id = event["SecretId"]
          step      = event["Step"]
          client    = boto3.client("secretsmanager", region_name=os.environ["AWS_REGION"])

          if step == "createSecret":
              client.put_secret_value(
                  SecretId=secret_id,
                  ClientRequestToken=event["ClientRequestToken"],
                  SecretString='{"password":"rotated-value"}',
                  VersionStages=["AWSPENDING"],
              )
          elif step == "finishSecret":
              client.update_secret_version_stage(
                  SecretId=secret_id,
                  VersionStage="AWSCURRENT",
                  MoveToVersionId=event["ClientRequestToken"],
              )
    EOF
  }
}

resource "aws_iam_role" "rotator" {
  name = "regression-test-secret-rotator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "rotator" {
  role = aws_iam_role.rotator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      },
    ]
  })
}

resource "aws_lambda_function" "rotator" {
  function_name    = "regression-test-secret-rotator"
  runtime          = "python3.12"
  handler          = "index.handler"
  role             = aws_iam_role.rotator.arn
  filename         = data.archive_file.rotator_zip.output_path
  source_code_hash = data.archive_file.rotator_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  kms_key_arn      = var.kms_key_arn

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    }
  }

  tags = var.tags
}

resource "aws_lambda_permission" "rotator" {
  function_name  = aws_lambda_function.rotator.function_name
  action         = "lambda:InvokeFunction"
  principal      = "secretsmanager.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------
# Pass secret — rotation enabled at 30-day cadence
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "pass" {
  name                    = "regression-test/db-password-pass"
  description             = "Database password — rotation enabled"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_rotation" "pass" {
  secret_id           = aws_secretsmanager_secret.pass.id
  rotation_lambda_arn = aws_lambda_function.rotator.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# ---------------------------------------------------------------------------
# SecretsManager.1 fail — no rotation configured (absence = violation)
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "no_rotation_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                    = "regression-test/db-password-fail"
  description             = "Database password — no rotation (intentional violation)"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 7

  # No aws_secretsmanager_secret_rotation resource — intentional violation
  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "SecretsManager.1"
  })
}
