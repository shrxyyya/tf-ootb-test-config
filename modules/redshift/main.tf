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

resource "aws_redshift_subnet_group" "main" {
  name        = "regression-test-redshift"
  subnet_ids  = var.private_subnet_ids
  description = "Redshift subnet group covering private subnets for regression test workloads."

  tags = merge(var.tags, {
    Name = "regression-test-redshift"
  })
}

resource "aws_security_group" "redshift" {
  name        = "redshift-regression-test"
  description = "Allow Redshift traffic on port 5439 from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "Redshift from private subnets"
    from_port   = 5439
    to_port     = 5439
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
    Name = "redshift-regression-test"
  })
}

resource "aws_s3_bucket" "audit_logs" {
  bucket_prefix = "redshift-audit-logs-regression-"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "redshift-audit-logs-regression"
  })
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "expire-audit-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

resource "aws_redshift_parameter_group" "pass" {
  name        = "regression-test-redshift-pass"
  family      = "redshift-1.0"
  description = "Redshift parameter group with SSL required (compliant)."

  parameter {
    name  = "require_ssl"
    value = "true"
  }

  tags = merge(var.tags, {
    Name = "regression-test-redshift-pass"
  })
}

resource "aws_redshift_parameter_group" "ssl_fail" {
  name        = "regression-test-redshift-ssl-fail"
  family      = "redshift-1.0"
  description = "Redshift parameter group with SSL disabled — intentional violation for Redshift.2."

  parameter {
    name  = "require_ssl"
    value = "false"
  }

  tags = merge(var.tags, {
    Name = "regression-test-redshift-ssl-fail"
  })
}

# ---------------------------------------------------------------------------
# Pass cluster — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "pass" {
  cluster_identifier = "regression-test-pass"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = false
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

resource "aws_redshift_logging" "pass" {
  cluster_identifier   = aws_redshift_cluster.pass.id
  log_destination_type = "s3"
  bucket_name          = aws_s3_bucket.audit_logs.bucket
  s3_key_prefix        = "redshift/"
}

# ---------------------------------------------------------------------------
# Redshift.1 — redshift-cluster-public-access-check
# fail: publicly_accessible = true
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-public-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = true # intentional violation
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name            = "regression-test-public-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.1"
  })
}

# ---------------------------------------------------------------------------
# Redshift.10 — redshift-cluster-should-be-encrypted-at-rest
# fail: encrypted = false, kms_key_id omitted
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-encrypted-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted = false # intentional violation

  publicly_accessible   = false
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name            = "regression-test-encrypted-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.10"
  })
}

# ---------------------------------------------------------------------------
# Redshift.2 — redshift-cluster-should-be-encrypted-at-transit
# fail: parameter_group with require_ssl=false
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "ssl_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-ssl-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = false
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.ssl_fail.name # intentional violation

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name            = "regression-test-ssl-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.2"
  })
}

# ---------------------------------------------------------------------------
# Redshift.3 — redshift-cluster-automated-snapshot-retention-enabled
# fail: automated_snapshot_retention_period = 1
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "snapshot_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-snapshot-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = false
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 1 # intentional violation

  tags = merge(var.tags, {
    Name            = "regression-test-snapshot-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.3"
  })
}

# ---------------------------------------------------------------------------
# Redshift.4 — redshift-cluster-audit-logging-enabled
# fail: logging { enable = false }
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-logging-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = false
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name            = "regression-test-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.4"
  })
}

# ---------------------------------------------------------------------------
# Redshift.7 — redshift-cluster-enhanced-vpc-routing-enabled
# fail: enhanced_vpc_routing = false
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "vpc_routing_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-vpc-routing-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = false
  enhanced_vpc_routing  = false # intentional violation
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name            = "regression-test-vpc-routing-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.7"
  })
}

# ---------------------------------------------------------------------------
# Redshift.8 — redshift-cluster-default-admin-check
# fail: master_username = "awsuser" (Redshift default)
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "admin_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-admin-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "awsuser" # intentional violation — Redshift default username
  master_password = "ChangeMe2024!"
  database_name   = "appdb"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = false
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name            = "regression-test-admin-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.8"
  })
}

# ---------------------------------------------------------------------------
# Redshift.9 — redshift-cluster-default-db-name-check
# fail: database_name = "dev" (Redshift default)
# ---------------------------------------------------------------------------

resource "aws_redshift_cluster" "dbname_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-dbname-fail"
  node_type          = "dc2.large"
  number_of_nodes    = 2

  master_username = "clusteradmin"
  master_password = "ChangeMe2024!"
  database_name   = "dev" # intentional violation — Redshift default database name

  encrypted  = true
  kms_key_id = var.kms_key_arn

  publicly_accessible   = false
  enhanced_vpc_routing  = true
  allow_version_upgrade = true
  skip_final_snapshot   = true
  apply_immediately     = true

  vpc_security_group_ids       = [aws_security_group.redshift.id]
  cluster_subnet_group_name    = aws_redshift_subnet_group.main.name
  cluster_parameter_group_name = aws_redshift_parameter_group.pass.name

  automated_snapshot_retention_period = 7

  tags = merge(var.tags, {
    Name            = "regression-test-dbname-fail"
    compliance_test = "intentional_violation"
    controls        = "Redshift.9"
  })
}
