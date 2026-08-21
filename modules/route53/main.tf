terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
    # Route53 query logs MUST be delivered to CloudWatch Logs in us-east-1
    # regardless of the deployment region. The aws.us_east_1 alias is
    # configured by the root module and passed in via the providers argument.
    # See: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/query-logs.html
  }
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Route53.2 — route-53-public-hosted-zones-should-log-dns-queries
# Pass: public zone with query logging enabled
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "pass" {
  name = "regression-test-pass.example.com"

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# Route53 query log groups MUST reside in us-east-1.
resource "aws_cloudwatch_log_group" "dns" {
  provider = aws.us_east_1

  name              = "/aws/route53/${aws_route53_zone.pass.name}"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "regression-test-route53-dns" })
}

# Resource policy allowing Route53 to write to the log group.
resource "aws_cloudwatch_log_resource_policy" "route53_dns_log" {
  provider = aws.us_east_1

  policy_name = "regression-test-route53-query-logging"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "route53.amazonaws.com"
      }
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/route53/*:*"
    }]
  })
}

resource "aws_route53_query_log" "pass" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53_dns_log]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.dns.arn
  zone_id                  = aws_route53_zone.pass.zone_id
}

# ---------------------------------------------------------------------------
# Route53.2 — fail: public zone with NO query logging attached
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "no_logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "regression-test-fail.example.com"
  # aws_route53_query_log intentionally omitted — intentional violation

  tags = merge(var.tags, {
    Name            = "regression-test-fail"
    compliance_test = "intentional_violation"
    controls        = "Route53.2"
  })
}
