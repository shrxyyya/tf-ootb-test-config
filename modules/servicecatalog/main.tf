terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {}

# ---------------------------------------------------------------------------
# Shared Service Catalog portfolio
# ---------------------------------------------------------------------------

resource "aws_servicecatalog_portfolio" "main" {
  name          = "regression-test"
  description   = "Regression test portfolio for compliance policy testing."
  provider_name = "Security Team"

  tags = merge(var.tags, { Name = "regression-test" })
}

# ---------------------------------------------------------------------------
# ServiceCatalog.1 — service-catalog-shared-within-organization-only
# Pass: share type = ORGANIZATION (shares within the org hierarchy)
# ---------------------------------------------------------------------------

resource "aws_servicecatalog_portfolio_share" "pass" {
  portfolio_id      = aws_servicecatalog_portfolio.main.id
  type              = "ORGANIZATION"
  principal_id      = data.aws_organizations_organization.current.arn
  share_tag_options = true
}

# ---------------------------------------------------------------------------
# ServiceCatalog.1 — fail: share type = ACCOUNT (external account share)
# Note: aws_servicecatalog_portfolio_share does not support tags;
# the intentional_violation tag is placed on the portfolio via a separate
# tagged aws_servicecatalog_portfolio resource for the fail case.
# ---------------------------------------------------------------------------

resource "aws_servicecatalog_portfolio" "fail" {
  count = var.create_failing_resources ? 1 : 0

  name          = "regression-test-fail"
  description   = "Regression test portfolio — intentional violation."
  provider_name = "Security Team"

  tags = merge(var.tags, {
    Name            = "regression-test-fail"
    compliance_test = "intentional_violation"
    controls        = "ServiceCatalog.1"
  })
}

resource "aws_servicecatalog_portfolio_share" "account_fail" {
  count = var.create_failing_resources ? 1 : 0

  portfolio_id = aws_servicecatalog_portfolio.fail[0].id
  type         = "ACCOUNT" # intentional violation — external account, not org
  principal_id = "123456789012"
}
