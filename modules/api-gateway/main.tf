# ---------------------------------------------------------------------------
# modules/api-gateway/main.tf
#
# Security controls covered:
#   APIGateway.1  — REST/WebSocket stage execution logging enabled
#   APIGateway.3  — REST stage X-Ray tracing enabled
#   APIGateway.4  — REST stage associated with a WAF Web ACL
#   APIGateway.5  — REST cache encryption enabled
#   APIGateway.8  — HTTP API routes specify an authorization type
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Shared REST API infrastructure
# ---------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "main" {
  name        = "regression-test"
  description = "Regression test REST API for API Gateway security controls"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mock" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.get.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_method.get,
    aws_api_gateway_integration.mock,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/regression-test"
  retention_in_days = 30
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Pass REST stage
#   APIGateway.1 — logging enabled (INFO, access_log_settings)
#   APIGateway.3 — xray_tracing_enabled = true
#   APIGateway.4 — web_acl_arn set
#   APIGateway.5 — cache enabled and encrypted
# ---------------------------------------------------------------------------

resource "aws_api_gateway_stage" "pass" {
  rest_api_id           = aws_api_gateway_rest_api.main.id
  deployment_id         = aws_api_gateway_deployment.main.id
  stage_name            = "prod"
  xray_tracing_enabled  = true
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = "$context.requestId $context.status $context.httpMethod $context.resourcePath $context.responseLength"
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "pass" {
  resource_arn = aws_api_gateway_stage.pass.arn
  web_acl_arn  = var.wafv2_web_acl_arn
}

resource "aws_api_gateway_method_settings" "pass" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.pass.stage_name
  method_path = "*/*"

  settings {
    logging_level        = "INFO"
    data_trace_enabled   = false
    metrics_enabled      = true
    caching_enabled      = true
    cache_data_encrypted = true
  }
}

# ---------------------------------------------------------------------------
# Fail: APIGateway.1 — logging disabled (no access_log_settings, level=OFF)
# ---------------------------------------------------------------------------

resource "aws_api_gateway_stage" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id           = aws_api_gateway_rest_api.main.id
  deployment_id         = aws_api_gateway_deployment.main.id
  stage_name            = "logging-fail"
  xray_tracing_enabled  = true
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  # intentional violation: no access_log_settings, execution logging=OFF via method settings

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "APIGateway.1"
  })
}

resource "aws_api_gateway_method_settings" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.logging_fail[0].stage_name
  method_path = "*/*"

  settings {
    logging_level        = "OFF" # intentional violation
    data_trace_enabled   = false
    metrics_enabled      = true
    caching_enabled      = true
    cache_data_encrypted = true
  }
}

# ---------------------------------------------------------------------------
# Fail: APIGateway.3 — X-Ray tracing disabled
# ---------------------------------------------------------------------------

resource "aws_api_gateway_stage" "xray_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id           = aws_api_gateway_rest_api.main.id
  deployment_id         = aws_api_gateway_deployment.main.id
  stage_name            = "xray-fail"
  xray_tracing_enabled  = false # intentional violation
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = "$context.requestId $context.status $context.httpMethod $context.resourcePath $context.responseLength"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "APIGateway.3"
  })
}

resource "aws_api_gateway_method_settings" "xray_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.xray_fail[0].stage_name
  method_path = "*/*"

  settings {
    logging_level        = "INFO"
    data_trace_enabled   = false
    metrics_enabled      = true
    caching_enabled      = true
    cache_data_encrypted = true
  }
}

# ---------------------------------------------------------------------------
# Fail: APIGateway.4 — no WAF Web ACL association
# ---------------------------------------------------------------------------

resource "aws_api_gateway_stage" "waf_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id           = aws_api_gateway_rest_api.main.id
  deployment_id         = aws_api_gateway_deployment.main.id
  stage_name            = "waf-fail"
  xray_tracing_enabled  = true
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"
  # intentional violation: no web_acl_arn

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = "$context.requestId $context.status $context.httpMethod $context.resourcePath $context.responseLength"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "APIGateway.4"
  })
}

resource "aws_api_gateway_method_settings" "waf_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.waf_fail[0].stage_name
  method_path = "*/*"

  settings {
    logging_level        = "INFO"
    data_trace_enabled   = false
    metrics_enabled      = true
    caching_enabled      = true
    cache_data_encrypted = true
  }
}

# ---------------------------------------------------------------------------
# Fail: APIGateway.5 — cache enabled but NOT encrypted
# ---------------------------------------------------------------------------

resource "aws_api_gateway_stage" "cache_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id           = aws_api_gateway_rest_api.main.id
  deployment_id         = aws_api_gateway_deployment.main.id
  stage_name            = "cache-fail"
  xray_tracing_enabled  = true
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = "$context.requestId $context.status $context.httpMethod $context.resourcePath $context.responseLength"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "APIGateway.5"
  })
}

resource "aws_api_gateway_method_settings" "cache_fail" {
  count = var.create_failing_resources ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.cache_fail[0].stage_name
  method_path = "*/*"

  settings {
    logging_level        = "INFO"
    data_trace_enabled   = false
    metrics_enabled      = true
    caching_enabled      = true
    cache_data_encrypted = false # intentional violation
  }
}

# ---------------------------------------------------------------------------
# APIGateway.8 — HTTP API routes must specify an authorization type
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "http" {
  name          = "regression-test-http"
  protocol_type = "HTTP"
  description   = "Regression test HTTP API for APIGateway.8"
  tags          = var.tags
}

# Pass: route specifies JWT authorization
resource "aws_apigatewayv2_route" "pass" {
  api_id             = aws_apigatewayv2_api.http.id
  route_key          = "GET /items"
  authorization_type = "JWT"
}

# Fail: route specifies NONE authorization — intentional violation
resource "aws_apigatewayv2_route" "auth_fail" {
  count = var.create_failing_resources ? 1 : 0

  api_id             = aws_apigatewayv2_api.http.id
  route_key          = "POST /items"
  authorization_type = "NONE" # intentional violation
}
