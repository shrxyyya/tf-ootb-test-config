terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Shared DMS subnet group
# ---------------------------------------------------------------------------

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "regression-test"
  replication_subnet_group_description = "Regression test DMS subnet group"
  subnet_ids                           = var.private_subnet_ids

  tags = merge(var.tags, { Name = "regression-test-dms" })
}

# ---------------------------------------------------------------------------
# DMS.1 — dms-replication-instances-should-not-be-public
# DMS.6 — dms-auto-minor-version-upgrade-check
# Pass: publicly_accessible = false, auto_minor_version_upgrade = true
# ---------------------------------------------------------------------------

resource "aws_dms_replication_instance" "pass" {
  replication_instance_id     = "regression-test-pass"
  replication_instance_class  = "dms.t3.micro"
  allocated_storage           = 20
  publicly_accessible         = false
  auto_minor_version_upgrade  = true
  multi_az                    = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  apply_immediately           = true

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# DMS.1 — fail: publicly_accessible = true
# ---------------------------------------------------------------------------

resource "aws_dms_replication_instance" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_instance_id     = "regression-test-public-fail"
  replication_instance_class  = "dms.t3.micro"
  allocated_storage           = 20
  publicly_accessible         = true # intentional violation
  auto_minor_version_upgrade  = true
  multi_az                    = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  apply_immediately           = true

  tags = merge(var.tags, {
    Name            = "regression-test-public-fail"
    compliance_test = "intentional_violation"
    controls        = "DMS.1"
  })
}

# ---------------------------------------------------------------------------
# DMS.6 — fail: auto_minor_version_upgrade = false
# ---------------------------------------------------------------------------

resource "aws_dms_replication_instance" "upgrade_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_instance_id     = "regression-test-upgrade-fail"
  replication_instance_class  = "dms.t3.micro"
  allocated_storage           = 20
  publicly_accessible         = false
  auto_minor_version_upgrade  = false # intentional violation
  multi_az                    = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  apply_immediately           = true

  tags = merge(var.tags, {
    Name            = "regression-test-upgrade-fail"
    compliance_test = "intentional_violation"
    controls        = "DMS.6"
  })
}

# ---------------------------------------------------------------------------
# DMS.9 — dms-endpoints-should-use-ssl
# Pass: ssl_mode = require
# ---------------------------------------------------------------------------

resource "aws_dms_endpoint" "pass" {
  endpoint_id   = "regression-test-pass"
  endpoint_type = "source"
  engine_name   = "mysql"
  server_name   = "db.example.internal"
  port          = 3306
  username      = "dmsuser"
  password      = "Ch@ngeMe2024!"
  ssl_mode      = "require"

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# DMS.9 — fail: ssl_mode = none
# ---------------------------------------------------------------------------

resource "aws_dms_endpoint" "ssl_fail" {
  count = var.create_failing_resources ? 1 : 0

  endpoint_id   = "regression-test-ssl-fail"
  endpoint_type = "source"
  engine_name   = "mysql"
  server_name   = "db.example.internal"
  port          = 3306
  username      = "dmsuser"
  password      = "Ch@ngeMe2024!"
  ssl_mode      = "none" # intentional violation

  tags = merge(var.tags, {
    Name            = "regression-test-ssl-fail"
    compliance_test = "intentional_violation"
    controls        = "DMS.9"
  })
}
