terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Shared infrastructure — always created
# ---------------------------------------------------------------------------

resource "aws_docdb_subnet_group" "main" {
  name        = "regression-test-docdb"
  subnet_ids  = var.private_subnet_ids
  description = "DocumentDB subnet group covering private subnets for regression test workloads."

  tags = merge(var.tags, {
    Name = "regression-test-docdb"
  })
}

resource "aws_security_group" "docdb" {
  name        = "docdb-regression-test"
  description = "Allow DocumentDB traffic on port 27017 from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "MongoDB protocol from private subnets"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : ["10.0.0.0/8"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "docdb-regression-test"
  })
}

resource "aws_docdb_cluster_parameter_group" "pass" {
  name        = "regression-test-docdb-pass"
  family      = "docdb5.0"
  description = "DocumentDB cluster parameter group with audit logging enabled (compliant)."

  parameter {
    name  = "audit_logs"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "regression-test-docdb-pass"
  })
}

resource "aws_docdb_cluster_parameter_group" "audit_fail" {
  name        = "regression-test-docdb-audit-fail"
  family      = "docdb5.0"
  description = "DocumentDB cluster parameter group with audit logging disabled — intentional violation for DocumentDB.4."

  parameter {
    name  = "audit_logs"
    value = "disabled"
  }

  tags = merge(var.tags, {
    Name = "regression-test-docdb-audit-fail"
  })
}

# ---------------------------------------------------------------------------
# Pass cluster — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_docdb_cluster" "pass" {
  cluster_identifier = "regression-test-pass"

  engine         = "docdb"
  engine_version = "5.0.0"

  master_username = "docdbadmin"
  master_password = "Ch@ngeMe2024!"

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period = 7

  deletion_protection = true

  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.pass.name

  vpc_security_group_ids = [aws_security_group.docdb.id]
  db_subnet_group_name   = aws_docdb_subnet_group.main.name

  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

resource "aws_docdb_cluster_instance" "pass" {
  cluster_identifier = aws_docdb_cluster.pass.id
  instance_class     = "db.t3.medium"
  engine             = "docdb"
  apply_immediately  = true

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# DocumentDB.1 — docdb-cluster-storage-encrypted
# fail: storage_encrypted = false
# ---------------------------------------------------------------------------

resource "aws_docdb_cluster" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-encrypted-fail"

  engine         = "docdb"
  engine_version = "5.0.0"

  master_username = "docdbadmin"
  master_password = "Ch@ngeMe2024!"

  storage_encrypted = false # intentional violation

  backup_retention_period = 7

  deletion_protection = true

  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.pass.name

  vpc_security_group_ids = [aws_security_group.docdb.id]
  db_subnet_group_name   = aws_docdb_subnet_group.main.name

  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-encrypted-fail"
    compliance_test = "intentional_violation"
    controls        = "DocumentDB.1"
  })
}

# ---------------------------------------------------------------------------
# DocumentDB.2 — docdb-cluster-backup-retention-check
# fail: backup_retention_period = 1
# ---------------------------------------------------------------------------

resource "aws_docdb_cluster" "backup_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-backup-fail"

  engine         = "docdb"
  engine_version = "5.0.0"

  master_username = "docdbadmin"
  master_password = "Ch@ngeMe2024!"

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period = 1 # intentional violation

  deletion_protection = true

  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.pass.name

  vpc_security_group_ids = [aws_security_group.docdb.id]
  db_subnet_group_name   = aws_docdb_subnet_group.main.name

  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-backup-fail"
    compliance_test = "intentional_violation"
    controls        = "DocumentDB.2"
  })
}

# ---------------------------------------------------------------------------
# DocumentDB.4 — docdb-cluster-audit-logging-enabled
# fail: db_cluster_parameter_group_name = audit_fail (audit_logs=disabled)
# ---------------------------------------------------------------------------

resource "aws_docdb_cluster" "audit_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-audit-fail"

  engine         = "docdb"
  engine_version = "5.0.0"

  master_username = "docdbadmin"
  master_password = "Ch@ngeMe2024!"

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period = 7

  deletion_protection = true

  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.audit_fail.name # intentional violation

  vpc_security_group_ids = [aws_security_group.docdb.id]
  db_subnet_group_name   = aws_docdb_subnet_group.main.name

  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-audit-fail"
    compliance_test = "intentional_violation"
    controls        = "DocumentDB.4"
  })
}

# ---------------------------------------------------------------------------
# DocumentDB.5 — docdb-cluster-deletion-protection-enabled
# fail: deletion_protection = false
# ---------------------------------------------------------------------------

resource "aws_docdb_cluster" "deletion_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-deletion-fail"

  engine         = "docdb"
  engine_version = "5.0.0"

  master_username = "docdbadmin"
  master_password = "Ch@ngeMe2024!"

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period = 7

  deletion_protection = false # intentional violation

  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.pass.name

  vpc_security_group_ids = [aws_security_group.docdb.id]
  db_subnet_group_name   = aws_docdb_subnet_group.main.name

  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-deletion-fail"
    compliance_test = "intentional_violation"
    controls        = "DocumentDB.5"
  })
}
