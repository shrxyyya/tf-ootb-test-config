terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Shared infrastructure — always created
# ---------------------------------------------------------------------------

resource "aws_security_group" "opensearch" {
  name        = "opensearch-regression-test"
  description = "Allow HTTPS traffic on port 443 from private subnets to OpenSearch."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
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
    Name = "opensearch-regression-test"
  })
}

resource "aws_cloudwatch_log_group" "opensearch" {
  name              = "/aws/opensearch/regression-test"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "opensearch-regression-test"
  })
}

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "regression-test-opensearch-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "es.amazonaws.com" }
      Action = [
        "logs:PutLogEvents",
        "logs:CreateLogStream",
      ]
      Resource = "${aws_cloudwatch_log_group.opensearch.arn}:*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Pass domain — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "pass" {
  domain_name    = "regression-test-pass"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Ch@ngeMe2024!"
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# OpenSearch.1 — opensearch-encrypted-at-rest
# fail: encrypt_at_rest { enabled = false }
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name    = "regression-test-enc-fail"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = false # intentional violation
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Ch@ngeMe2024!"
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-enc-fail"
    compliance_test = "intentional_violation"
    controls        = "OpenSearch.1"
  })
}

# ---------------------------------------------------------------------------
# OpenSearch.2 — opensearch-in-vpc-only
# fail: no vpc_options block
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "vpc_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name    = "regression-test-vpc-fail"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  # vpc_options intentionally omitted — intentional violation

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Ch@ngeMe2024!"
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-vpc-fail"
    compliance_test = "intentional_violation"
    controls        = "OpenSearch.2"
  })
}

# ---------------------------------------------------------------------------
# OpenSearch.3 — opensearch-node-to-node-encryption-check
# fail: node_to_node_encryption { enabled = false }
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "n2n_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name    = "regression-test-n2n-fail"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = false # intentional violation
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Ch@ngeMe2024!"
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-n2n-fail"
    compliance_test = "intentional_violation"
    controls        = "OpenSearch.3"
  })
}

# ---------------------------------------------------------------------------
# OpenSearch.4 — opensearch-logs-to-cloudwatch
# fail: no log_publishing_options blocks
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name    = "regression-test-logging-fail"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Ch@ngeMe2024!"
    }
  }

  # log_publishing_options intentionally omitted — intentional violation

  tags = merge(var.tags, {
    Name            = "regression-test-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "OpenSearch.4"
  })
}

# ---------------------------------------------------------------------------
# OpenSearch.6 — opensearch-data-node-fault-tolerance
# fail: instance_count = 1, zone_awareness_enabled = false
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "nodes_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name    = "regression-test-nodes-fail"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 1     # intentional violation
    zone_awareness_enabled = false # intentional violation
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 1)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Ch@ngeMe2024!"
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-nodes-fail"
    compliance_test = "intentional_violation"
    controls        = "OpenSearch.6"
  })
}

# ---------------------------------------------------------------------------
# OpenSearch.7 — opensearch-access-control-enabled
# fail: advanced_security_options { enabled = false }
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "access_control_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name    = "regression-test-ac-fail"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled = false # intentional violation
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-ac-fail"
    compliance_test = "intentional_violation"
    controls        = "OpenSearch.7"
  })
}

# ---------------------------------------------------------------------------
# OpenSearch.8 — opensearch-https-required
# fail: domain_endpoint_options { enforce_https = false }
# ---------------------------------------------------------------------------

resource "aws_opensearch_domain" "https_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name    = "regression-test-https-fail"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = false # intentional violation
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Ch@ngeMe2024!"
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-https-fail"
    compliance_test = "intentional_violation"
    controls        = "OpenSearch.8"
  })
}
