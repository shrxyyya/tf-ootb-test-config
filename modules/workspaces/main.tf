terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# NOTE: WorkSpaces is expensive (~$25+/month per workspace). Destroy promptly
# after regression testing. A SimpleAD directory is required and incurs its
# own cost (~$0.05/hour). Bundle wsb-bh8rsxt14 is Standard with Windows 10.

# ---------------------------------------------------------------------------
# Required Simple AD directory (WorkSpaces prerequisite)
# ---------------------------------------------------------------------------

resource "aws_directory_service_directory" "main" {
  name     = "regression.test.internal"
  password = "Ch@ngeMe2024!"
  type     = "SimpleAD"
  size     = "Small"

  vpc_settings {
    vpc_id     = var.vpc_id
    subnet_ids = slice(var.private_subnet_ids, 0, 2)
  }

  tags = merge(var.tags, { Name = "regression-test-workspaces-ad" })
}


# ---------------------------------------------------------------------------
# WorkSpaces.1 + WorkSpaces.2 — volumes encrypted at rest
# Pass: both root and user volume encryption enabled
# ---------------------------------------------------------------------------

resource "aws_workspaces_workspace" "pass" {
  directory_id = aws_directory_service_directory.main.id
  bundle_id    = var.workspaces_bundle_id
  user_name    = "testuser"

  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key          = var.kms_key_arn

  workspace_properties {
    compute_type_name                         = "VALUE"
    root_volume_size_gib                      = 80
    user_volume_size_gib                      = 50
    running_mode                              = "AUTO_STOP"
    running_mode_auto_stop_timeout_in_minutes = 60
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# WorkSpaces.2 — fail: root_volume_encryption_enabled = false
# ---------------------------------------------------------------------------

resource "aws_workspaces_workspace" "root_fail" {
  count = var.create_failing_resources ? 1 : 0

  directory_id = aws_directory_service_directory.main.id
  bundle_id    = var.workspaces_bundle_id
  user_name    = "testuser-root-fail"

  root_volume_encryption_enabled = false # intentional violation
  user_volume_encryption_enabled = true
  volume_encryption_key          = var.kms_key_arn

  workspace_properties {
    compute_type_name                         = "VALUE"
    root_volume_size_gib                      = 80
    user_volume_size_gib                      = 50
    running_mode                              = "AUTO_STOP"
    running_mode_auto_stop_timeout_in_minutes = 60
  }

  tags = merge(var.tags, {
    Name            = "regression-test-root-fail"
    compliance_test = "intentional_violation"
    controls        = "WorkSpaces.2"
  })
}

# ---------------------------------------------------------------------------
# WorkSpaces.1 — fail: user_volume_encryption_enabled = false
# ---------------------------------------------------------------------------

resource "aws_workspaces_workspace" "user_fail" {
  count = var.create_failing_resources ? 1 : 0

  directory_id = aws_directory_service_directory.main.id
  bundle_id    = var.workspaces_bundle_id
  user_name    = "testuser-user-fail"

  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = false # intentional violation
  volume_encryption_key          = var.kms_key_arn

  workspace_properties {
    compute_type_name                         = "VALUE"
    root_volume_size_gib                      = 80
    user_volume_size_gib                      = 50
    running_mode                              = "AUTO_STOP"
    running_mode_auto_stop_timeout_in_minutes = 60
  }

  tags = merge(var.tags, {
    Name            = "regression-test-user-fail"
    compliance_test = "intentional_violation"
    controls        = "WorkSpaces.1"
  })
}
