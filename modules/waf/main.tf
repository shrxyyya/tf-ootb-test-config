# ---------------------------------------------------------------------------
# modules/waf/main.tf
#
# Security controls covered:
#   WAF.1  / waf-classic-logging-enabled
#   WAF.6  / waf-global-rule-not-empty
#   WAF.7  / waf-global-rulegroup-not-empty
#   WAF.8  / waf-global-webacl-not-empty
#   WAF.10 / wafv2-webacl-not-empty
#   WAF.12 / wafv2-rulegroup-logging-enabled
#
# NOTE: WAF Classic global resources (aws_waf_*) are us-east-1 only.
#       WAFv2 supports REGIONAL and CLOUDFRONT scope.
# ---------------------------------------------------------------------------

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
# WAFv2 — CW log group for logging configuration
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "waf" {
  name              = "/aws/wafv2/regression-test"
  retention_in_days = 30

  tags = var.tags
}

# ---------------------------------------------------------------------------
# WAFv2 Web ACL — pass (has rules, has logging)
# ---------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "pass" {
  name  = "regression-test-pass"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "RegressionTestWAFPass"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# WAFv2 logging configuration on pass Web ACL — satisfies WAF.12
resource "aws_wafv2_web_acl_logging_configuration" "pass" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.pass.arn
}

# Optional ALB association — created when create_failing_resources is set
# (alb_arn is always provided from root; count avoids apply-time dependency error)
resource "aws_wafv2_web_acl_association" "pass" {
  count = var.create_failing_resources ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.pass.arn
}

# ---------------------------------------------------------------------------
# WAF.10 fail — WAFv2 Web ACL with no rules
# ---------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "empty_fail" {
  count = var.create_failing_resources ? 1 : 0

  name  = "regression-test-empty-fail"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # No rules — intentional violation for WAF.10

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "EmptyWAFMetric"
    sampled_requests_enabled   = false
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "WAF.10"
  })
}

# No aws_wafv2_web_acl_logging_configuration for empty_fail — also fails WAF.12

# ---------------------------------------------------------------------------
# WAFv2 Rule Group — pass (has at least one rule)
# ---------------------------------------------------------------------------

resource "aws_wafv2_ip_set" "main" {
  name               = "regression-test-ipset"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["10.0.0.0/8"]

  tags = var.tags
}

resource "aws_wafv2_rule_group" "pass" {
  name     = "regression-test-rule-group"
  scope    = "REGIONAL"
  capacity = 100

  rule {
    name     = "BlockPrivateRanges"
    priority = 1

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.main.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockPrivateRangesMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "RegressionTestRuleGroupPass"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# WAF Classic — shared IP set used by pass rule and web ACL
# ---------------------------------------------------------------------------

resource "aws_waf_ipset" "main" {
  name = "regression-test-ipset"

  ip_set_descriptors {
    type  = "IPV4"
    value = "10.0.0.0/8"
  }
}

# ---------------------------------------------------------------------------
# WAF.6 — WAF Classic rule pass (has predicate) / fail (empty)
# ---------------------------------------------------------------------------

resource "aws_waf_rule" "pass" {
  name        = "regression-test-pass"
  metric_name = "regressionTestPass"

  predicates {
    data_id = aws_waf_ipset.main.id
    negated = false
    type    = "IPMatch"
  }

  tags = var.tags
}

resource "aws_waf_rule" "empty_fail" {
  count = var.create_failing_resources ? 1 : 0

  name        = "regression-test-empty-fail"
  metric_name = "regressionTestEmptyFail"

  # No predicates — intentional violation for WAF.6

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "WAF.6"
  })
}

# ---------------------------------------------------------------------------
# WAF.7 — WAF Classic rule group pass (has rule) / fail (empty)
# ---------------------------------------------------------------------------

resource "aws_waf_rule_group" "pass" {
  name        = "regression-test-pass"
  metric_name = "regressionTestRuleGroupPass"

  activated_rule {
    action { type = "COUNT" }
    priority = 1
    rule_id  = aws_waf_rule.pass.id
  }

  tags = var.tags
}

resource "aws_waf_rule_group" "empty_fail" {
  count = var.create_failing_resources ? 1 : 0

  name        = "regression-test-empty-fail"
  metric_name = "regressionTestRuleGroupEmptyFail"

  # No activated_rules — intentional violation for WAF.7

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "WAF.7"
  })
}

# ---------------------------------------------------------------------------
# WAF.8 — WAF Classic Web ACL pass (has rules) / fail (empty)
# ---------------------------------------------------------------------------

resource "aws_waf_web_acl" "pass" {
  name        = "regression-test-pass"
  metric_name = "regressionTestWebACLPass"

  default_action {
    type = "ALLOW"
  }

  rules {
    action { type = "COUNT" }
    priority = 1
    rule_id  = aws_waf_rule.pass.id
  }

  tags = var.tags
}

resource "aws_waf_web_acl" "empty_fail" {
  count = var.create_failing_resources ? 1 : 0

  name        = "regression-test-empty-fail"
  metric_name = "regressionTestWebACLEmptyFail"

  default_action {
    type = "ALLOW"
  }

  # No rules — intentional violation for WAF.8

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "WAF.8"
  })
}

# ---------------------------------------------------------------------------
# WAF.1 — WAF Classic logging enabled
#
# Requires a Kinesis Firehose with name prefix "aws-waf-logs-"
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
  name               = "regression-test-waf-firehose"
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
}

resource "aws_iam_role_policy" "firehose" {
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_policy.json
}

# WAF Classic logging requires Firehose name prefix "aws-waf-logs-"
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "aws-waf-logs-regression-test"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = var.logs_bucket_arn
    prefix             = "waf-classic/"
    buffering_size     = 5
    buffering_interval = 300
    compression_format = "GZIP"
  }

  tags = var.tags
}

# WAF.1 pass — aws_waf_web_acl_logging_configuration was removed in AWS provider v5.
# WAF Classic logging via Terraform is no longer supported; configure via AWS Console
# or use WAFv2 (aws_wafv2_web_acl_logging_configuration) instead.

# WAF.1 fail — empty_fail web ACL has no logging configuration (absence = violation)
