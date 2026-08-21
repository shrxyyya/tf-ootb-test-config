terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Shared infrastructure — always created, no pass/fail variants
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name        = "regression-test-db"
  subnet_ids  = var.private_subnet_ids
  description = "Multi-AZ DB subnet group covering private subnets for regression test workloads."

  tags = merge(var.tags, {
    Name = "regression-test-db"
  })
}

resource "aws_security_group" "rds" {
  name        = "rds-regression-test"
  description = "Allow MySQL traffic from within the VPC; used by regression-test RDS instances."
  vpc_id      = var.vpc_id

  # Allow MySQL from self (app tier → DB tier pattern)
  ingress {
    description = "MySQL from self"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = true
  }

  # Non-default port used by pass resources
  ingress {
    description = "MySQL non-default port from self"
    from_port   = 3307
    to_port     = 3307
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "rds-regression-test"
  })
}

# ---------------------------------------------------------------------------
# RDS.2 / CIS-2.2.3 — rds-instance-should-be-private
#
# pass  → aws_db_instance.pass        publicly_accessible = false
# fail  → aws_db_instance.public_fail publicly_accessible = true
# ---------------------------------------------------------------------------

resource "aws_db_instance" "pass" {
  identifier = "regression-test-pass"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# RDS.2 / CIS-2.2.3 — intentional violation: publicly_accessible = true
resource "aws_db_instance" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-public-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true # intentional violation
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-public-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.2,CIS-2.2.3"
  })
}

# ---------------------------------------------------------------------------
# RDS.3 / CIS-2.2.1 — rds-encryption-at-rest-enabled
#
# fail → storage_encrypted = false, kms_key_id omitted
# ---------------------------------------------------------------------------

resource "aws_db_instance" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-encrypted-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = false # intentional violation
  kms_key_id            = ""    # intentional violation

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-encrypted-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.3,CIS-2.2.1"
  })
}

# ---------------------------------------------------------------------------
# RDS.5 / CIS-2.2.4 — rds-ensure-multi-az-configuration
#
# fail → multi_az = false
# ---------------------------------------------------------------------------

resource "aws_db_instance" "multiaz_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-multiaz-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = false # intentional violation
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-multiaz-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.5,CIS-2.2.4"
  })
}

# ---------------------------------------------------------------------------
# RDS.8 — rds-ensure-deletion-protection-enabled
#
# fail → deletion_protection = false
# ---------------------------------------------------------------------------

resource "aws_db_instance" "deletion_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-deletion-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = false # intentional violation

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-deletion-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.8"
  })
}

# ---------------------------------------------------------------------------
# RDS.11 — rds-ensure-automatic-backups-enabled
#
# fail → backup_retention_period = 0
# ---------------------------------------------------------------------------

resource "aws_db_instance" "backup_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-backup-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 0 # intentional violation
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-backup-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.11"
  })
}

# ---------------------------------------------------------------------------
# RDS.13 / CIS-2.2.2 — rds-ensure-automatic-minor-version-upgrades-enabled
#
# fail → auto_minor_version_upgrade = false
# ---------------------------------------------------------------------------

resource "aws_db_instance" "upgrade_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-upgrade-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = false # intentional violation
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-upgrade-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.13,CIS-2.2.2"
  })
}

# ---------------------------------------------------------------------------
# RDS.6 — rds-ensure-monitoring-configured
#
# fail → monitoring_interval = 0 (Enhanced Monitoring disabled)
# ---------------------------------------------------------------------------

resource "aws_db_instance" "monitoring_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-monitoring-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 0 # intentional violation — Enhanced Monitoring disabled

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-monitoring-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.6"
  })
}

# ---------------------------------------------------------------------------
# RDS.10 — rds-ensure-cluster-and-db-instance-iam-auth-configured
#
# fail → iam_database_authentication_enabled = false
# ---------------------------------------------------------------------------

resource "aws_db_instance" "iam_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-iam-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = false # intentional violation

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-iam-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.10"
  })
}

# ---------------------------------------------------------------------------
# RDS.24 / RDS.25 — rds-cluster-default-admin-check / rds-instance-default-admin-check
#
# fail → username = "admin" (engine default)
# ---------------------------------------------------------------------------

resource "aws_db_instance" "admin_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-admin-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = "admin" # intentional violation — default admin username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-admin-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.24,RDS.25"
  })
}

# ---------------------------------------------------------------------------
# RDS.23 — rds-ensure-no-default-port
#
# fail → port = 3306 (MySQL default port)
# ---------------------------------------------------------------------------

resource "aws_db_instance" "port_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-port-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3306 # intentional violation — MySQL default port

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-port-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.23"
  })
}

# ---------------------------------------------------------------------------
# RDS.17 — rds-copy-tags-to-snapshot-configured
#
# fail → copy_tags_to_snapshot = false
# ---------------------------------------------------------------------------

resource "aws_db_instance" "tags_fail" {
  count = var.create_failing_resources ? 1 : 0

  identifier = "regression-test-tags-fail"

  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3307

  username = var.db_username
  password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = false # intentional violation
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = merge(var.tags, {
    Name            = "regression-test-tags-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.17"
  })
}

# ---------------------------------------------------------------------------
# Aurora cluster — RDS.27 (rds-cluster-encrypted-at-rest)
#                  RDS.10 (iam_database_authentication at cluster level)
#
# pass cluster  → aws_rds_cluster.pass + aws_rds_cluster_instance.pass (×2)
# fail cluster  → aws_rds_cluster.encrypted_fail  storage_encrypted=false
# ---------------------------------------------------------------------------

resource "aws_rds_cluster" "pass" {
  cluster_identifier = "regression-test-aurora-pass"

  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.05.2"

  master_username = "clusteradmin"
  master_password = var.db_password

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  deletion_protection     = true

  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  backtrack_window      = 259200 # 3 days in seconds

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name = "regression-test-aurora-pass"
  })
}

resource "aws_rds_cluster_instance" "pass" {
  count = 2

  identifier         = "regression-test-aurora-pass-${count.index}"
  cluster_identifier = aws_rds_cluster.pass.id

  engine         = "aurora-mysql"
  instance_class = "db.t3.medium"

  publicly_accessible        = false
  auto_minor_version_upgrade = true

  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  tags = merge(var.tags, {
    Name = "regression-test-aurora-pass-${count.index}"
  })
}

# RDS.27 — intentional violation: storage_encrypted = false
resource "aws_rds_cluster" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_identifier = "regression-test-aurora-encrypted-fail"

  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.05.2"

  master_username = "clusteradmin"
  master_password = var.db_password

  storage_encrypted = false # intentional violation
  # kms_key_id omitted — encryption disabled

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  deletion_protection     = true

  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true
  backtrack_window      = 259200

  skip_final_snapshot = true
  apply_immediately   = true

  tags = merge(var.tags, {
    Name            = "regression-test-aurora-encrypted-fail"
    compliance_test = "intentional_violation"
    controls        = "RDS.27"
  })
}
