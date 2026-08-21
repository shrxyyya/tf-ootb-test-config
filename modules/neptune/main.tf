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

resource "aws_neptune_subnet_group" "main" {
  name        = "regression-test-neptune"
  subnet_ids  = var.private_subnet_ids
  description = "Neptune subnet group covering private subnets for regression test workloads."

  tags = merge(var.tags, {
    Name = "regression-test-neptune"
  })
}

resource "aws_security_group" "neptune" {
  name        = "neptune-regression-test"
  description = "Allow Neptune traffic on port 8182 from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "Neptune Bolt/SPARQL/Gremlin from private subnets"
    from_port   = 8182
    to_port     = 8182
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
    Name = "neptune-regression-test"
  })
}

resource "aws_neptune_cluster_parameter_group" "pass" {
  name        = "regression-test-neptune-pass"
  family      = "neptune1.3"
  description = "Neptune cluster parameter group with audit logging enabled (compliant)."

  parameter {
    name  = "neptune_enable_audit_log"
    value = "1"
  }

  tags = merge(var.tags, {
    Name = "regression-test-neptune-pass"
  })
}

resource "aws_neptune_cluster_parameter_group" "audit_fail" {
  name        = "regression-test-neptune-audit-fail"
  family      = "neptune1.3"
  description = "Neptune cluster parameter group with audit logging disabled — intentional violation for Neptune.2."

  parameter {
    name  = "neptune_enable_audit_log"
    value = "0"
  }

  tags = merge(var.tags, {
    Name = "regression-test-neptune-audit-fail"
  })
}

# ---------------------------------------------------------------------------
# Pass cluster — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_neptune_cluster" "pass" {
  cluster_identifier = "regression-test-pass"

  engine         = "neptune"
  engine_version = "1.3.1.0"

  storage_encrypted = true

  deletion_protection = true

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true

  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.pass.name

  vpc_security_group_ids    = [aws_security_group.neptune.id]
  neptune_subnet_group_name = aws_neptune_subnet_group.main.name

  enable_cloudwatch_logs_exports = ["audit"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

resource "aws_neptune_cluster_instance" "pass" {
  cluster_identifier = aws_neptune_cluster.pass.id
  instance_class     = "db.t3.medium"
  engine             = "neptune"
  apply_immediately  = true

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# Neptune.1 — neptune-cluster-encryption-at-rest-enabled
# fail: storage_encrypted = false
# ---------------------------------------------------------------------------

resource "aws_neptune_cluster" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-encrypted-fail"

  engine         = "neptune"
  engine_version = "1.3.1.0"

  storage_encrypted = false # intentional violation

  deletion_protection = true

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true

  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.pass.name

  vpc_security_group_ids    = [aws_security_group.neptune.id]
  neptune_subnet_group_name = aws_neptune_subnet_group.main.name

  enable_cloudwatch_logs_exports = ["audit"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-encrypted-fail"
    compliance_test = "intentional_violation"
    controls        = "Neptune.1"
  })
}

# ---------------------------------------------------------------------------
# Neptune.2 — neptune-cluster-audit-logs-publishing-enabled
# fail: neptune_cluster_parameter_group_name = audit_fail (audit_log = 0)
# ---------------------------------------------------------------------------

resource "aws_neptune_cluster" "audit_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-audit-fail"

  engine         = "neptune"
  engine_version = "1.3.1.0"

  storage_encrypted = true

  deletion_protection = true

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true

  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.audit_fail.name # intentional violation

  vpc_security_group_ids    = [aws_security_group.neptune.id]
  neptune_subnet_group_name = aws_neptune_subnet_group.main.name

  enable_cloudwatch_logs_exports = ["audit"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-audit-fail"
    compliance_test = "intentional_violation"
    controls        = "Neptune.2"
  })
}

# ---------------------------------------------------------------------------
# Neptune.4 — neptune-cluster-deletion-protection-enabled
# fail: deletion_protection = false
# ---------------------------------------------------------------------------

resource "aws_neptune_cluster" "deletion_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-deletion-fail"

  engine         = "neptune"
  engine_version = "1.3.1.0"

  storage_encrypted = true

  deletion_protection = false # intentional violation

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true

  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.pass.name

  vpc_security_group_ids    = [aws_security_group.neptune.id]
  neptune_subnet_group_name = aws_neptune_subnet_group.main.name

  enable_cloudwatch_logs_exports = ["audit"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-deletion-fail"
    compliance_test = "intentional_violation"
    controls        = "Neptune.4"
  })
}

# ---------------------------------------------------------------------------
# Neptune.5 — neptune-cluster-automated-backups-enabled
# fail: backup_retention_period = 1
# ---------------------------------------------------------------------------

resource "aws_neptune_cluster" "backup_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-backup-fail"

  engine         = "neptune"
  engine_version = "1.3.1.0"

  storage_encrypted = true

  deletion_protection = true

  backup_retention_period = 1 # intentional violation
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true

  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.pass.name

  vpc_security_group_ids    = [aws_security_group.neptune.id]
  neptune_subnet_group_name = aws_neptune_subnet_group.main.name

  enable_cloudwatch_logs_exports = ["audit"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-backup-fail"
    compliance_test = "intentional_violation"
    controls        = "Neptune.5"
  })
}

# ---------------------------------------------------------------------------
# Neptune.7 — neptune-cluster-db-auth-enabled
# fail: iam_database_authentication_enabled = false
# ---------------------------------------------------------------------------

resource "aws_neptune_cluster" "auth_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-auth-fail"

  engine         = "neptune"
  engine_version = "1.3.1.0"

  storage_encrypted = true

  deletion_protection = true

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = false # intentional violation

  copy_tags_to_snapshot = true

  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.pass.name

  vpc_security_group_ids    = [aws_security_group.neptune.id]
  neptune_subnet_group_name = aws_neptune_subnet_group.main.name

  enable_cloudwatch_logs_exports = ["audit"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-auth-fail"
    compliance_test = "intentional_violation"
    controls        = "Neptune.7"
  })
}

# ---------------------------------------------------------------------------
# Neptune.8 — neptune-cluster-copy-tags-to-snapshot-enabled
# fail: copy_tags_to_snapshot = false
# ---------------------------------------------------------------------------

resource "aws_neptune_cluster" "tags_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-tags-fail"

  engine         = "neptune"
  engine_version = "1.3.1.0"

  storage_encrypted = true

  deletion_protection = true

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = false # intentional violation

  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.pass.name

  vpc_security_group_ids    = [aws_security_group.neptune.id]
  neptune_subnet_group_name = aws_neptune_subnet_group.main.name

  enable_cloudwatch_logs_exports = ["audit"]

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-tags-fail"
    compliance_test = "intentional_violation"
    controls        = "Neptune.8"
  })
}
