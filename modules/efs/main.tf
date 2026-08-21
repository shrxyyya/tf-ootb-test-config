# ---------------------------------------------------------------------------
# modules/efs/main.tf
#
# Security controls covered:
#   EFS.1  — efs-filesystem-encrypted
#   EFS.3  — efs-access-point-should-enforce-root-directory
#   EFS.4  — efs-access-point-should-enforce-user-identity
#   EFS.7  — efs-automatic-backups-enabled
#   EFS.8  — efs-file-systems-should-be-encrypted-at-rest
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
# Shared security group
# ---------------------------------------------------------------------------

resource "aws_security_group" "efs" {
  name        = "regression-test-efs"
  description = "NFS access for regression-test EFS"
  vpc_id      = var.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "regression-test-efs"
  })
}

# ---------------------------------------------------------------------------
# Pass file system — encrypted, backups enabled
# ---------------------------------------------------------------------------

resource "aws_efs_file_system" "pass" {
  encrypted        = true
  kms_key_id       = var.kms_key_arn
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

resource "aws_efs_backup_policy" "pass" {
  file_system_id = aws_efs_file_system.pass.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "pass" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.pass.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# ---------------------------------------------------------------------------
# Pass access point — enforces root directory and POSIX user identity
# ---------------------------------------------------------------------------

resource "aws_efs_access_point" "pass" {
  file_system_id = aws_efs_file_system.pass.id

  root_directory {
    path = "/app"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# EFS.1 / EFS.8 fail — encryption disabled
# ---------------------------------------------------------------------------

resource "aws_efs_file_system" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  encrypted        = false # intentional violation
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EFS.1,EFS.8"
  })
}

# ---------------------------------------------------------------------------
# EFS.7 fail — backup policy disabled
# ---------------------------------------------------------------------------

resource "aws_efs_file_system" "backup_fail" {
  count = var.create_failing_resources ? 1 : 0

  encrypted        = true
  kms_key_id       = var.kms_key_arn
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EFS.7"
  })
}

resource "aws_efs_backup_policy" "backup_fail" {
  count = var.create_failing_resources ? 1 : 0

  file_system_id = aws_efs_file_system.backup_fail[0].id

  backup_policy {
    status = "DISABLED" # intentional violation
  }
}

# ---------------------------------------------------------------------------
# EFS.3 fail — access point root path is / (no enforced subdirectory)
# ---------------------------------------------------------------------------

resource "aws_efs_access_point" "root_dir_fail" {
  count = var.create_failing_resources ? 1 : 0

  file_system_id = aws_efs_file_system.pass.id

  root_directory {
    path = "/" # intentional violation: no subdirectory enforcement
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EFS.3"
  })
}

# ---------------------------------------------------------------------------
# EFS.4 fail — access point without posix_user (no user identity enforcement)
# ---------------------------------------------------------------------------

resource "aws_efs_access_point" "no_user_fail" {
  count = var.create_failing_resources ? 1 : 0

  file_system_id = aws_efs_file_system.pass.id

  root_directory {
    path = "/data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  # No posix_user block — intentional violation for EFS.4

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EFS.4"
  })
}
