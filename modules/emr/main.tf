terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# EMR.2 — emr-block-public-access-enabled
# Singleton — toggle-driven. create_failing_resources = true → BPA disabled.
# ---------------------------------------------------------------------------

resource "aws_emr_block_public_access_configuration" "main" {
  block_public_security_group_rules = var.create_failing_resources ? false : true
  # intentional_violation when create_failing_resources = true (BPA disabled)
}

# ---------------------------------------------------------------------------
# EMR.3 + EMR.4 — emr-security-configuration-encryption-rest
#               + emr-security-configuration-encryption-transit
# Pass: both at-rest and in-transit encryption enabled.
# Note: aws_emr_security_configuration does not support tags.
# ---------------------------------------------------------------------------

resource "aws_emr_security_configuration" "pass" {
  name = "regression-test-pass"

  configuration = jsonencode({
    EncryptionConfiguration = {
      EnableInTransitEncryption = true
      EnableAtRestEncryption    = true
      AtRestEncryptionConfiguration = {
        S3EncryptionConfiguration = {
          EncryptionMode = "SSE-KMS"
          AwsKmsKey      = var.kms_key_arn
        }
        LocalDiskEncryptionConfiguration = {
          EncryptionKeyProviderType = "AwsKms"
          AwsKmsKey                 = var.kms_key_arn
        }
      }
      InTransitEncryptionConfiguration = {
        TLSCertificateConfiguration = {
          CertificateProviderType = "PEM"
          S3Object                = "s3://${var.logs_bucket_id}/emr-certs/cert.zip"
        }
      }
    }
  })
}

# ---------------------------------------------------------------------------
# EMR.3 — fail: EnableAtRestEncryption = false
# Note: aws_emr_security_configuration does not support tags block.
# ---------------------------------------------------------------------------

resource "aws_emr_security_configuration" "no_rest_fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "regression-test-no-rest-fail"

  # intentional violation: at-rest encryption disabled
  configuration = jsonencode({
    EncryptionConfiguration = {
      EnableInTransitEncryption = true
      EnableAtRestEncryption    = false # intentional violation
      InTransitEncryptionConfiguration = {
        TLSCertificateConfiguration = {
          CertificateProviderType = "PEM"
          S3Object                = "s3://${var.logs_bucket_id}/emr-certs/cert.zip"
        }
      }
    }
  })
}

# ---------------------------------------------------------------------------
# EMR.4 — fail: EnableInTransitEncryption = false
# ---------------------------------------------------------------------------

resource "aws_emr_security_configuration" "no_transit_fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "regression-test-no-transit-fail"

  # intentional violation: in-transit encryption disabled
  configuration = jsonencode({
    EncryptionConfiguration = {
      EnableInTransitEncryption = false # intentional violation
      EnableAtRestEncryption    = true
      AtRestEncryptionConfiguration = {
        S3EncryptionConfiguration = {
          EncryptionMode = "SSE-KMS"
          AwsKmsKey      = var.kms_key_arn
        }
        LocalDiskEncryptionConfiguration = {
          EncryptionKeyProviderType = "AwsKms"
          AwsKmsKey                 = var.kms_key_arn
        }
      }
    }
  })
}
