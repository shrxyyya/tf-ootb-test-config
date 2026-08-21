terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Shared IAM role for AppSync → CloudWatch Logs
# ---------------------------------------------------------------------------

resource "aws_iam_role" "appsync_logs" {
  name = "regression-test-appsync-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "regression-test-appsync-logs" })
}

resource "aws_iam_role_policy_attachment" "appsync_logs" {
  role       = aws_iam_role.appsync_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppSyncPushToCloudWatchLogs"
}

# ---------------------------------------------------------------------------
# AppSync.2 + AppSync.5 + AppSync.1/6 — pass API (OIDC auth, field logging,
# cache with encryption at rest and in transit)
# ---------------------------------------------------------------------------

resource "aws_appsync_graphql_api" "pass" {
  name                = "regression-test-pass"
  authentication_type = "OPENID_CONNECT"

  openid_connect_config {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_regression_test"
    auth_ttl = 3600
    iat_ttl  = 3600
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
    exclude_verbose_content  = false
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

resource "aws_appsync_api_cache" "pass" {
  api_id               = aws_appsync_graphql_api.pass.id
  type                 = "SMALL"
  ttl                  = 300
  api_caching_behavior = "FULL_REQUEST_CACHING"

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
}

# ---------------------------------------------------------------------------
# AppSync.5 — fail: API_KEY authentication
# Requires a separate API so the cache resources don't conflict.
# ---------------------------------------------------------------------------

resource "aws_appsync_graphql_api" "api_key_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                = "regression-test-api-key-fail"
  authentication_type = "API_KEY" # intentional violation

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-api-key-fail"
    compliance_test = "intentional_violation"
    controls        = "AppSync.5"
  })
}

# ---------------------------------------------------------------------------
# AppSync.2 — fail: field_log_level = "NONE"
# ---------------------------------------------------------------------------

resource "aws_appsync_graphql_api" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                = "regression-test-logging-fail"
  authentication_type = "OPENID_CONNECT"

  openid_connect_config {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_regression_test"
    auth_ttl = 3600
    iat_ttl  = 3600
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "NONE" # intentional violation
  }

  tags = merge(var.tags, {
    Name            = "regression-test-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "AppSync.2"
  })
}

# ---------------------------------------------------------------------------
# AppSync.1 — fail: at_rest_encryption_enabled = false
# Needs its own API; only one cache per API is allowed.
# ---------------------------------------------------------------------------

resource "aws_appsync_graphql_api" "cache_rest_fail_api" {
  count = var.create_failing_resources ? 1 : 0

  name                = "regression-test-cache-rest-fail"
  authentication_type = "OPENID_CONNECT"

  openid_connect_config {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_regression_test"
    auth_ttl = 3600
    iat_ttl  = 3600
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-cache-rest-fail"
    compliance_test = "intentional_violation"
    controls        = "AppSync.1"
  })
}

resource "aws_appsync_api_cache" "rest_fail" {
  count = var.create_failing_resources ? 1 : 0

  api_id               = aws_appsync_graphql_api.cache_rest_fail_api[0].id
  type                 = "SMALL"
  ttl                  = 300
  api_caching_behavior = "FULL_REQUEST_CACHING"

  at_rest_encryption_enabled = false # intentional violation
  transit_encryption_enabled = true
}

# ---------------------------------------------------------------------------
# AppSync.6 — fail: transit_encryption_enabled = false
# ---------------------------------------------------------------------------

resource "aws_appsync_graphql_api" "cache_transit_fail_api" {
  count = var.create_failing_resources ? 1 : 0

  name                = "regression-test-cache-transit-fail"
  authentication_type = "OPENID_CONNECT"

  openid_connect_config {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_regression_test"
    auth_ttl = 3600
    iat_ttl  = 3600
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-cache-transit-fail"
    compliance_test = "intentional_violation"
    controls        = "AppSync.6"
  })
}

resource "aws_appsync_api_cache" "transit_fail" {
  count = var.create_failing_resources ? 1 : 0

  api_id               = aws_appsync_graphql_api.cache_transit_fail_api[0].id
  type                 = "SMALL"
  ttl                  = 300
  api_caching_behavior = "FULL_REQUEST_CACHING"

  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # intentional violation
}
