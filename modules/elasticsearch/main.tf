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
# Shared security group (mirrors opensearch module pattern)
# ---------------------------------------------------------------------------

resource "aws_security_group" "elasticsearch" {
  name        = "elasticsearch-regression-test"
  description = "Allow HTTPS traffic on port 443 from private subnets to Elasticsearch."
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

  tags = merge(var.tags, { Name = "elasticsearch-regression-test" })
}

resource "aws_cloudwatch_log_group" "elasticsearch" {
  name              = "/aws/elasticsearch/regression-test"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "elasticsearch-regression-test" })
}

resource "aws_cloudwatch_log_resource_policy" "elasticsearch" {
  policy_name = "regression-test-elasticsearch-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "es.amazonaws.com" }
      Action = [
        "logs:PutLogEvents",
        "logs:CreateLogStream",
      ]
      Resource = "${aws_cloudwatch_log_group.elasticsearch.arn}:*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Pass domain — fully compliant, all controls satisfied
# Elasticsearch.1 — encrypted at rest
# Elasticsearch.2 — in VPC
# Elasticsearch.3 — node-to-node encryption
# Elasticsearch.4 — logs to CloudWatch
# Elasticsearch.5 — enforce HTTPS
# Elasticsearch.6 — at least 3 data nodes
# Elasticsearch.7 — dedicated master nodes (fault tolerance)
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "pass" {
  domain_name           = "regression-test-pass"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    dedicated_master_enabled = true
    dedicated_master_type    = "t3.small.elasticsearch"
    dedicated_master_count   = 3
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.elasticsearch.id]
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
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# Elasticsearch.1 — fail: encrypt_at_rest { enabled = false }
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "encrypted_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name           = "regression-test-enc-fail"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    dedicated_master_enabled = true
    dedicated_master_type    = "t3.small.elasticsearch"
    dedicated_master_count   = 3
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.elasticsearch.id]
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
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-enc-fail"
    compliance_test = "intentional_violation"
    controls        = "Elasticsearch.1"
  })
}

# ---------------------------------------------------------------------------
# Elasticsearch.2 — fail: no vpc_options block
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "vpc_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name           = "regression-test-vpc-fail"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    dedicated_master_enabled = true
    dedicated_master_type    = "t3.small.elasticsearch"
    dedicated_master_count   = 3
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
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-vpc-fail"
    compliance_test = "intentional_violation"
    controls        = "Elasticsearch.2"
  })
}

# ---------------------------------------------------------------------------
# Elasticsearch.3 — fail: node_to_node_encryption { enabled = false }
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "n2n_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name           = "regression-test-n2n-fail"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    dedicated_master_enabled = true
    dedicated_master_type    = "t3.small.elasticsearch"
    dedicated_master_count   = 3
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.elasticsearch.id]
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
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-n2n-fail"
    compliance_test = "intentional_violation"
    controls        = "Elasticsearch.3"
  })
}

# ---------------------------------------------------------------------------
# Elasticsearch.4 — fail: no log_publishing_options
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name           = "regression-test-logging-fail"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    dedicated_master_enabled = true
    dedicated_master_type    = "t3.small.elasticsearch"
    dedicated_master_count   = 3
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.elasticsearch.id]
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
    controls        = "Elasticsearch.4"
  })
}

# ---------------------------------------------------------------------------
# Elasticsearch.5 — fail: enforce_https = false
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "https_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name           = "regression-test-https-fail"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    dedicated_master_enabled = true
    dedicated_master_type    = "t3.small.elasticsearch"
    dedicated_master_count   = 3
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.elasticsearch.id]
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
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-https-fail"
    compliance_test = "intentional_violation"
    controls        = "Elasticsearch.5"
  })
}

# ---------------------------------------------------------------------------
# Elasticsearch.6 — fail: instance_count = 1, zone_awareness_enabled = false
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "nodes_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name           = "regression-test-nodes-fail"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 1     # intentional violation
    zone_awareness_enabled = false # intentional violation
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 1)
    security_group_ids = [aws_security_group.elasticsearch.id]
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
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-nodes-fail"
    compliance_test = "intentional_violation"
    controls        = "Elasticsearch.6"
  })
}

# ---------------------------------------------------------------------------
# Elasticsearch.7 — fail: no dedicated master nodes
# ---------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "master_fail" {
  count = var.create_failing_resources ? 1 : 0

  domain_name           = "regression-test-master-fail"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type          = "t3.small.elasticsearch"
    instance_count         = 3
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    dedicated_master_enabled = false # intentional violation
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, 3)
    security_group_ids = [aws_security_group.elasticsearch.id]
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
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elasticsearch.arn
    log_type                 = "AUDIT_LOGS"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-master-fail"
    compliance_test = "intentional_violation"
    controls        = "Elasticsearch.7"
  })
}
