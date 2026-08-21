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

resource "aws_elasticache_subnet_group" "main" {
  name        = "regression-test-elasticache"
  subnet_ids  = var.private_subnet_ids
  description = "ElastiCache subnet group covering private subnets for regression test workloads."

  tags = merge(var.tags, {
    Name = "regression-test-elasticache"
  })
}

resource "aws_security_group" "elasticache" {
  name        = "elasticache-regression-test"
  description = "Allow Redis traffic on port 6379 from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis from private subnets"
    from_port   = 6379
    to_port     = 6379
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
    Name = "elasticache-regression-test"
  })
}

# ---------------------------------------------------------------------------
# Pass replication group — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "pass" {
  replication_group_id = "regression-pass"
  description          = "Pass replication group — fully compliant Redis cluster."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  transit_encryption_enabled = true
  auth_token                 = "SuperSecretAuthToken2024!"

  automatic_failover_enabled = true
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name = "regression-pass"
  })
}

# ---------------------------------------------------------------------------
# ElastiCache.1 — elasticache-redis-cluster-auto-backup-enabled
# fail: snapshot_retention_limit = 0
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "backup_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_group_id = "regression-backup-fail"
  description          = "Fail replication group — auto-backup disabled."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  transit_encryption_enabled = true
  auth_token                 = "SuperSecretAuthToken2024!"

  automatic_failover_enabled = true
  snapshot_retention_limit   = 0 # intentional violation
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name            = "regression-backup-fail"
    compliance_test = "intentional_violation"
    controls        = "ElastiCache.1"
  })
}

# ---------------------------------------------------------------------------
# ElastiCache.2 — elasticache-redis-cluster-auto-minor-version-upgrade-enabled
# fail: auto_minor_version_upgrade = false
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "upgrade_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_group_id = "regression-upgrade-fail"
  description          = "Fail replication group — auto minor version upgrade disabled."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  transit_encryption_enabled = true
  auth_token                 = "SuperSecretAuthToken2024!"

  automatic_failover_enabled = true
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = false # intentional violation
  apply_immediately          = true

  tags = merge(var.tags, {
    Name            = "regression-upgrade-fail"
    compliance_test = "intentional_violation"
    controls        = "ElastiCache.2"
  })
}

# ---------------------------------------------------------------------------
# ElastiCache.3 — elasticache-redis-replication-group-auto-failover-enabled
# fail: automatic_failover_enabled = false, num_cache_clusters = 1
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "failover_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_group_id = "regression-failover-fail"
  description          = "Fail replication group — auto failover disabled."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 1 # intentional violation — single node required when failover disabled
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  transit_encryption_enabled = true
  auth_token                 = "SuperSecretAuthToken2024!"

  automatic_failover_enabled = false # intentional violation
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name            = "regression-failover-fail"
    compliance_test = "intentional_violation"
    controls        = "ElastiCache.3"
  })
}

# ---------------------------------------------------------------------------
# ElastiCache.4 — elasticache-redis-replication-group-encryption-at-rest-enabled
# fail: at_rest_encryption_enabled = false
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "encryption_rest_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_group_id = "regression-enc-rest-fail"
  description          = "Fail replication group — at-rest encryption disabled."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = false # intentional violation

  transit_encryption_enabled = true
  auth_token                 = "SuperSecretAuthToken2024!"

  automatic_failover_enabled = true
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name            = "regression-enc-rest-fail"
    compliance_test = "intentional_violation"
    controls        = "ElastiCache.4"
  })
}

# ---------------------------------------------------------------------------
# ElastiCache.5 — elasticache-redis-replication-group-encryption-at-transit-enabled
# fail: transit_encryption_enabled = false, auth_token omitted
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "encryption_transit_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_group_id = "regression-enc-transit-fail"
  description          = "Fail replication group — in-transit encryption disabled."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  transit_encryption_enabled = false # intentional violation — auth_token omitted as a consequence

  automatic_failover_enabled = true
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name            = "regression-enc-transit-fail"
    compliance_test = "intentional_violation"
    controls        = "ElastiCache.5"
  })
}

# ---------------------------------------------------------------------------
# ElastiCache.6 — elasticache-redis-replication-group-redis-auth-enabled
# fail: transit_encryption_enabled = true but no auth_token
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "auth_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_group_id = "regression-auth-fail"
  description          = "Fail replication group — transit encryption on but AUTH token absent."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  transit_encryption_enabled = true
  # auth_token intentionally omitted — intentional violation

  automatic_failover_enabled = true
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name            = "regression-auth-fail"
    compliance_test = "intentional_violation"
    controls        = "ElastiCache.6"
  })
}

# ---------------------------------------------------------------------------
# ElastiCache.7 — elasticache-redis-cluster-non-default-subnet-enabled
# fail: subnet_group_name = "default" (simulates use of the default subnet group)
# ---------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "subnet_fail" {
  count = var.create_failing_resources ? 1 : 0

  replication_group_id = "regression-subnet-fail"
  description          = "Fail replication group — uses the default ElastiCache subnet group."

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = "default" # intentional violation — default subnet group
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  transit_encryption_enabled = true
  auth_token                 = "SuperSecretAuthToken2024!"

  automatic_failover_enabled = true
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name            = "regression-subnet-fail"
    compliance_test = "intentional_violation"
    controls        = "ElastiCache.7"
  })
}
