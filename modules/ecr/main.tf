# ---------------------------------------------------------------------------
# modules/ecr/main.tf
#
# Security controls covered:
#   ECR.1  — ecr-image-scanning-enabled
#   ECR.2  — ecr-tag-immutability-configured
#   ECR.3  — ecr-lifecycle-policy-configured
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Pass repository — scanning on, immutable tags, lifecycle policy
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "pass" {
  name                 = "regression-test/app-pass"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "pass" {
  repository = aws_ecr_repository.pass.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 14 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 14
      }
      action = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------
# ECR.1 fail — scan_on_push disabled
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "scanning_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                 = "regression-test/app-scanning-fail"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false # intentional violation
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "ECR.1"
  })
}

# ---------------------------------------------------------------------------
# ECR.2 fail — mutable tags
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "mutable_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                 = "regression-test/app-mutable-fail"
  image_tag_mutability = "MUTABLE" # intentional violation

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "ECR.2"
  })
}

# ---------------------------------------------------------------------------
# ECR.3 fail — no lifecycle policy (absence = violation)
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "no_lifecycle_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                 = "regression-test/app-no-lifecycle-fail"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  # No aws_ecr_lifecycle_policy — intentional violation for ECR.3
  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "ECR.3"
  })
}
