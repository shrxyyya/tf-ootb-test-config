# ---------------------------------------------------------------------------
# modules/lambda/main.tf
#
# Security controls covered:
#   Lambda.1  — lambda-function-public-access-prohibited
#   Lambda.2  — lambda-functions-should-use-supported-runtimes
#   Lambda.5  — lambda-vpc-multi-az-check
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

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Inline function zip
# ---------------------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source {
    content  = "def handler(event, context): return {'statusCode': 200, 'body': 'ok'}"
    filename = "index.py"
  }
}

# ---------------------------------------------------------------------------
# Shared infrastructure
# ---------------------------------------------------------------------------

resource "aws_security_group" "lambda" {
  name        = "regression-test-lambda"
  description = "Lambda functions — egress to AWS APIs only"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS to AWS service endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "regression-test-lambda"
  })
}

resource "aws_cloudwatch_log_group" "lambda_pass" {
  name              = "/aws/lambda/regression-test-pass"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# Lambda.2 / Lambda.5 — pass function
#
# Lambda.2 pass: runtime = "python3.12" (supported)
# Lambda.5 pass: vpc_config uses var.private_subnet_ids (multi-AZ)
# Lambda.1 pass: permission scoped to own account via source_arn
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "pass" {
  function_name                  = "regression-test-pass"
  runtime                        = "python3.12"
  handler                        = "index.handler"
  role                           = var.lambda_execution_role_arn
  filename                       = data.archive_file.lambda_zip.output_path
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 10
  kms_key_arn                    = var.kms_key_arn

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      LOG_LEVEL   = "INFO"
      ENVIRONMENT = "test"
    }
  }

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda_pass.name
    log_format = "JSON"
  }

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })

  depends_on = [aws_cloudwatch_log_group.lambda_pass]
}

# ---------------------------------------------------------------------------
# Lambda.1 — pass permission (scoped to own account via source_arn)
# ---------------------------------------------------------------------------

resource "aws_lambda_permission" "pass" {
  function_name = aws_lambda_function.pass.function_name
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:*/*/*"
}

# ---------------------------------------------------------------------------
# Lambda.2 — runtime_fail
#
# Intentional violation: runtime = "python3.7" (EOL / unsupported)
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "runtime_fail" {
  count = var.create_failing_resources ? 1 : 0

  function_name                  = "regression-test-runtime-fail"
  runtime                        = "python3.7" # intentional violation: EOL runtime
  handler                        = "index.handler"
  role                           = var.lambda_execution_role_arn
  filename                       = data.archive_file.lambda_zip.output_path
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 10
  kms_key_arn                    = var.kms_key_arn

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      LOG_LEVEL   = "INFO"
      ENVIRONMENT = "test"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-runtime-fail"
    compliance_test = "intentional_violation"
    controls        = "Lambda.2"
  })
}

# ---------------------------------------------------------------------------
# Lambda.1 — public_fail function + permission
#
# Intentional violation: resource-based policy grants principal="*"
# (no source_arn / source_account condition — public invoke access)
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  function_name                  = "regression-test-public-fail"
  runtime                        = "python3.12"
  handler                        = "index.handler"
  role                           = var.lambda_execution_role_arn
  filename                       = data.archive_file.lambda_zip.output_path
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 10
  kms_key_arn                    = var.kms_key_arn

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      LOG_LEVEL   = "INFO"
      ENVIRONMENT = "test"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-public-fail"
    compliance_test = "intentional_violation"
    controls        = "Lambda.1"
  })
}

resource "aws_lambda_permission" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  function_name = aws_lambda_function.public_fail[0].function_name
  action        = "lambda:InvokeFunction"
  principal     = "*" # intentional violation: wildcard principal, no source condition
}

# ---------------------------------------------------------------------------
# Lambda.5 — novpc_fail
#
# Intentional violation: no vpc_config block (function not VPC-attached)
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "novpc_fail" {
  count = var.create_failing_resources ? 1 : 0

  function_name                  = "regression-test-novpc-fail"
  runtime                        = "python3.12"
  handler                        = "index.handler"
  role                           = var.lambda_execution_role_arn
  filename                       = data.archive_file.lambda_zip.output_path
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 10
  kms_key_arn                    = var.kms_key_arn

  # intentional violation: vpc_config omitted — function has no VPC attachment

  environment {
    variables = {
      LOG_LEVEL   = "INFO"
      ENVIRONMENT = "test"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-novpc-fail"
    compliance_test = "intentional_violation"
    controls        = "Lambda.5"
  })
}
