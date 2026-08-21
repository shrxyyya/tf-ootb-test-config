terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Shared CloudWatch log group for firewall flow logs
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "firewall" {
  name              = "/aws/network-firewall/regression-test"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "regression-test-network-firewall" })
}

# ---------------------------------------------------------------------------
# NetworkFirewall.3 — network-firewall-policy-rule-group-associated
# Shared stateless rule group referenced by the pass policy.
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_rule_group" "pass" {
  name     = "regression-test-pass"
  type     = "STATELESS"
  capacity = 100

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1

          rule_definition {
            actions = ["aws:drop"]

            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }

              destination {
                address_definition = "0.0.0.0/0"
              }

              protocols = [6]
            }
          }
        }
      }
    }
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# NetworkFirewall.4 + .5 + .3 — default actions drop, rule group associated
# Pass policy: stateless_default_actions = ["aws:drop"],
#              stateless_fragment_default_actions = ["aws:drop"],
#              stateless_rule_group_reference present
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall_policy" "pass" {
  name = "regression-test-pass"

  firewall_policy {
    stateless_default_actions          = ["aws:drop"]
    stateless_fragment_default_actions = ["aws:drop"]

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.pass.arn
    }
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# NetworkFirewall.6 + .7 + .9 — deletion protection, subnet change protection
# Pass firewall: delete_protection = true, subnet_change_protection = true
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall" "pass" {
  name                = "regression-test-pass"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.pass.arn
  vpc_id              = var.vpc_id

  delete_protection                 = true
  firewall_policy_change_protection = true
  subnet_change_protection          = true

  subnet_mapping {
    subnet_id = var.private_subnet_ids[0]
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# NetworkFirewall.1 — network-firewall-logging-enabled
# Pass: flow logs → CloudWatch
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_logging_configuration" "pass" {
  firewall_arn = aws_networkfirewall_firewall.pass.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

# ---------------------------------------------------------------------------
# NetworkFirewall.9 — fail: delete_protection = false
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall" "deletion_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                = "regression-test-deletion-fail"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.pass.arn
  vpc_id              = var.vpc_id

  delete_protection        = false # intentional violation
  subnet_change_protection = true

  subnet_mapping {
    subnet_id = var.private_subnet_ids[0]
  }

  tags = merge(var.tags, {
    Name            = "regression-test-deletion-fail"
    compliance_test = "intentional_violation"
    controls        = "NetworkFirewall.9"
  })
}

# ---------------------------------------------------------------------------
# NetworkFirewall.7 — fail: subnet_change_protection = false
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall" "subnet_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                = "regression-test-subnet-fail"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.pass.arn
  vpc_id              = var.vpc_id

  delete_protection        = true
  subnet_change_protection = false # intentional violation

  subnet_mapping {
    subnet_id = var.private_subnet_ids[0]
  }

  tags = merge(var.tags, {
    Name            = "regression-test-subnet-fail"
    compliance_test = "intentional_violation"
    controls        = "NetworkFirewall.7"
  })
}

# ---------------------------------------------------------------------------
# NetworkFirewall.4 + .5 — fail: stateless default actions = "aws:pass"
# (both full packets and fragmented packets fail simultaneously)
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall_policy" "action_fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "regression-test-action-fail"

  firewall_policy {
    stateless_default_actions          = ["aws:pass"] # intentional violation
    stateless_fragment_default_actions = ["aws:pass"] # intentional violation
  }

  tags = merge(var.tags, {
    Name            = "regression-test-action-fail"
    compliance_test = "intentional_violation"
    controls        = "NetworkFirewall.4,NetworkFirewall.5"
  })
}

# ---------------------------------------------------------------------------
# NetworkFirewall.3 — fail: policy with no rule group reference
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall_policy" "norule_fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "regression-test-norule-fail"

  firewall_policy {
    stateless_default_actions          = ["aws:drop"]
    stateless_fragment_default_actions = ["aws:drop"]
    # stateless_rule_group_reference intentionally omitted — intentional violation
  }

  tags = merge(var.tags, {
    Name            = "regression-test-norule-fail"
    compliance_test = "intentional_violation"
    controls        = "NetworkFirewall.3"
  })
}
