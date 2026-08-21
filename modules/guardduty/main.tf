# ---------------------------------------------------------------------------
# modules/guardduty/main.tf
#
# Security controls covered:
#   guardduty-should-be-enabled
#   guardduty-s3-protection-should-be-enabled
#   guardduty-eks-audit-log-monitoring-should-be-enabled
#   guardduty-malware-protection-enabled
#   guardduty-runtime-monitoring-enabled
#
# SINGLETON — GuardDuty detector is account-scoped; toggle-driven.
#   create_failing_resources = true  → disabled detector + all protections off (intentional violations)
#   create_failing_resources = false → enabled detector + all protections on   (compliant)
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_guardduty_detector" "main" {
  enable = var.create_failing_resources ? false : true

  datasources {
    s3_logs {
      enable = var.create_failing_resources ? false : true
    }
    kubernetes {
      audit_logs {
        enable = var.create_failing_resources ? false : true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.create_failing_resources ? false : true
        }
      }
    }
  }

  tags = var.create_failing_resources ? merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "GuardDuty.1,GuardDuty.2,GuardDuty.3,GuardDuty.4,GuardDuty.8"
  }) : var.tags
}
