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

resource "aws_dax_subnet_group" "main" {
  name        = "regression-test-dax"
  subnet_ids  = var.private_subnet_ids
  description = "DAX subnet group covering private subnets for regression test workloads."
}

resource "aws_security_group" "dax" {
  name        = "dax-regression-test"
  description = "Allow DAX traffic on port 8111 (unencrypted) and 9111 (TLS) from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "DAX TLS from private subnets"
    from_port   = 9111
    to_port     = 9111
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
    Name = "dax-regression-test"
  })
}

resource "aws_iam_role" "dax" {
  name = "regression-test-dax-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dax.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "regression-test-dax-role"
  })
}

resource "aws_iam_role_policy" "dax" {
  name = "dax-dynamodb-access"
  role = aws_iam_role.dax.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:BatchGetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:DescribeTable",
        "dynamodb:ListTables",
      ]
      Resource = "*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Pass DynamoDB table — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "pass" {
  name         = "regression-test-pass"
  billing_mode = "PAY_PER_REQUEST"

  deletion_protection_enabled = true

  hash_key = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# DynamoDB.2 — dynamo-db-tables-point-in-time-recovery-enabled
# fail: point_in_time_recovery { enabled = false }
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "pitr_fail" {
  count = var.create_failing_resources ? 1 : 0

  name         = "regression-test-pitr-fail"
  billing_mode = "PAY_PER_REQUEST"

  deletion_protection_enabled = true

  hash_key = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false # intentional violation
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name            = "regression-test-pitr-fail"
    compliance_test = "intentional_violation"
    controls        = "DynamoDB.2"
  })
}

# ---------------------------------------------------------------------------
# DynamoDB.1 — dynamo-db-tables-scales-capacity-with-demand
# fail: billing_mode = "PROVISIONED" with no autoscaling attached
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "capacity_fail" {
  count = var.create_failing_resources ? 1 : 0

  name           = "regression-test-capacity-fail"
  billing_mode   = "PROVISIONED" # intentional violation — fixed capacity, no autoscaling
  read_capacity  = 5
  write_capacity = 5

  deletion_protection_enabled = true

  hash_key = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name            = "regression-test-capacity-fail"
    compliance_test = "intentional_violation"
    controls        = "DynamoDB.1"
  })
}

# ---------------------------------------------------------------------------
# DynamoDB.6 — dynamo-db-tables-delete-protection-enabled
# fail: deletion_protection_enabled = false
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "deletion_fail" {
  count = var.create_failing_resources ? 1 : 0

  name         = "regression-test-deletion-fail"
  billing_mode = "PAY_PER_REQUEST"

  deletion_protection_enabled = false # intentional violation

  hash_key = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name            = "regression-test-deletion-fail"
    compliance_test = "intentional_violation"
    controls        = "DynamoDB.6"
  })
}

# ---------------------------------------------------------------------------
# Pass DAX cluster — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_dax_cluster" "pass" {
  cluster_name       = "regression-test-pass"
  node_type          = "dax.t3.small"
  replication_factor = 1
  iam_role_arn       = aws_iam_role.dax.arn
  subnet_group_name  = aws_dax_subnet_group.main.name
  security_group_ids = [aws_security_group.dax.id]

  cluster_endpoint_encryption_type = "TLS"

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# DynamoDB.3 — dynamo-db-accelerator-clusters-encryption-at-rest-enabled
# fail: server_side_encryption { enabled = false }
# ---------------------------------------------------------------------------

resource "aws_dax_cluster" "encryption_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_name       = "reg-test-enc-fail"
  node_type          = "dax.t3.small"
  replication_factor = 1
  iam_role_arn       = aws_iam_role.dax.arn
  subnet_group_name  = aws_dax_subnet_group.main.name
  security_group_ids = [aws_security_group.dax.id]

  cluster_endpoint_encryption_type = "TLS"

  server_side_encryption {
    enabled = false # intentional violation
  }

  tags = merge(var.tags, {
    Name            = "regression-test-encryption-fail"
    compliance_test = "intentional_violation"
    controls        = "DynamoDB.3"
  })
}

# ---------------------------------------------------------------------------
# DynamoDB.7 — dynamo-db-accelerator-clusters-encryption-in-transit-enabled
# fail: cluster_endpoint_encryption_type = "NONE"
# ---------------------------------------------------------------------------

resource "aws_dax_cluster" "transit_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_name       = "reg-test-tls-fail"
  node_type          = "dax.t3.small"
  replication_factor = 1
  iam_role_arn       = aws_iam_role.dax.arn
  subnet_group_name  = aws_dax_subnet_group.main.name
  security_group_ids = [aws_security_group.dax.id]

  cluster_endpoint_encryption_type = "NONE" # intentional violation

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name            = "regression-test-transit-fail"
    compliance_test = "intentional_violation"
    controls        = "DynamoDB.7"
  })
}
