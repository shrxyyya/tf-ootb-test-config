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
# Shared IAM role for Transfer Family → CloudWatch Logs
# ---------------------------------------------------------------------------

resource "aws_iam_role" "transfer" {
  name = "regression-test-transfer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "transfer.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "regression-test-transfer" })
}

resource "aws_iam_role_policy" "transfer_logs" {
  name = "regression-test-transfer-logs"
  role = aws_iam_role.transfer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:CreateLogGroup",
        "logs:PutLogEvents",
      ]
      Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/transfer/*:*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "transfer" {
  name              = "/aws/transfer/regression-test"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "regression-test-transfer" })
}

# ---------------------------------------------------------------------------
# Shared security group for the Transfer Family VPC endpoint
# ---------------------------------------------------------------------------

resource "aws_security_group" "transfer" {
  name        = "regression-test-transfer"
  description = "Transfer Family SFTP from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "SFTP from private subnets"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "regression-test-transfer" })
}

# ---------------------------------------------------------------------------
# Transfer.2 — transfer-family-server-should-not-use-ftp
# Pass: protocols = ["SFTP"], VPC endpoint, logging enabled
# ---------------------------------------------------------------------------

resource "aws_transfer_server" "pass" {
  protocols              = ["SFTP"]
  endpoint_type          = "VPC"
  identity_provider_type = "SERVICE_MANAGED"
  logging_role           = aws_iam_role.transfer.arn

  structured_log_destinations = ["${aws_cloudwatch_log_group.transfer.arn}:*"]

  endpoint_details {
    vpc_id             = var.vpc_id
    subnet_ids         = [var.private_subnet_ids[0]]
    security_group_ids = [aws_security_group.transfer.id]
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# Transfer.2 — fail: protocols = ["FTP"], PUBLIC endpoint
# ---------------------------------------------------------------------------

resource "aws_transfer_server" "ftp_fail" {
  count = var.create_failing_resources ? 1 : 0

  protocols              = ["FTP"] # intentional violation
  endpoint_type          = "PUBLIC"
  identity_provider_type = "SERVICE_MANAGED"

  tags = merge(var.tags, {
    Name            = "regression-test-ftp-fail"
    compliance_test = "intentional_violation"
    controls        = "Transfer.2"
  })
}

# ---------------------------------------------------------------------------
# Transfer.3 — transfer-family-connectors-should-have-logging-enabled
# Pass: logging_role set
# ---------------------------------------------------------------------------

resource "aws_transfer_connector" "pass" {
  url          = "sftp://transfer.regression.test.internal"
  logging_role = aws_iam_role.transfer.arn
  access_role  = aws_iam_role.transfer.arn

  sftp_config {
    user_secret_id = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:regression-test-transfer-key"
  }

  tags = merge(var.tags, { Name = "regression-test-connector-pass" })
}

# ---------------------------------------------------------------------------
# Transfer.3 — fail: no logging_role
# ---------------------------------------------------------------------------

resource "aws_transfer_connector" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  url         = "sftp://transfer.regression.test.internal"
  access_role = aws_iam_role.transfer.arn
  # logging_role intentionally omitted — intentional violation

  sftp_config {
    user_secret_id = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:regression-test-transfer-key"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-connector-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "Transfer.3"
  })
}
