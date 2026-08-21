terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# ACM.1 — acm-pca-root-ca-disabled
# Pass: ROOT CA — will be DISABLED after certificate issuance.
# Note: aws_acmpca_certificate_authority starts PENDING_CERTIFICATE.
# A full self-signed root requires aws_acmpca_certificate + self-sign steps
# that are expensive and complex for regression testing. The ACTIVE vs
# DISABLED status distinction is what the policy evaluates; the fail resource
# below stays in ACTIVE state (the default after activation).
# ---------------------------------------------------------------------------

resource "aws_acmpca_certificate_authority" "pass" {
  type = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name = "regression-test-root-ca"
    }
  }

  permanent_deletion_time_in_days = 7

  tags = merge(var.tags, {
    Name = "regression-test-root-ca-pass"
  })
}

# ---------------------------------------------------------------------------
# ACM.1 — fail: ROOT CA left in ACTIVE status (never disabled)
# ---------------------------------------------------------------------------

resource "aws_acmpca_certificate_authority" "root_active_fail" {
  count = var.create_failing_resources ? 1 : 0

  type = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name = "regression-test-root-ca-fail"
    }
  }

  permanent_deletion_time_in_days = 7

  tags = merge(var.tags, {
    Name            = "regression-test-root-ca-fail"
    compliance_test = "intentional_violation"
    controls        = "ACM.1"
  })
}

# ---------------------------------------------------------------------------
# ACM.2 — acm-rsa-certificate-key-length-atleast-2048
# Pass: RSA_2048 — meets the minimum key length requirement.
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "pass" {
  domain_name       = "regression-test-pass.internal"
  validation_method = "DNS"
  key_algorithm     = "RSA_2048"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# ACM.2 — fail: EC_prime256v1 — not RSA >= 2048; policy should flag non-RSA
# or RSA below 2048. AWS no longer allows RSA_1024 via API; EC_prime256v1 is
# the practical "weak / non-compliant" alternative for this control.
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "weak_key_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name       = "regression-test-fail.internal"
  validation_method = "DNS"
  key_algorithm     = "EC_prime256v1" # intentional violation — not RSA >= 2048

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name            = "regression-test-weak-key-fail"
    compliance_test = "intentional_violation"
    controls        = "ACM.2"
  })
}
