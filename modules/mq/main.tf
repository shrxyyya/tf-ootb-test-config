terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Shared security group for Amazon MQ brokers
# ---------------------------------------------------------------------------

resource "aws_security_group" "mq" {
  name        = "regression-test-mq"
  description = "Allow ActiveMQ traffic from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "ActiveMQ console"
    from_port   = 8162
    to_port     = 8162
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "OpenWire / SSL"
    from_port   = 61617
    to_port     = 61617
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "regression-test-mq" })
}

# ---------------------------------------------------------------------------
# MQ.1 + MQ.2 — mq-auto-minor-version-upgrade-enabled
#              + mq-cloudwatch-audit-log-enabled
# Pass: audit = true, auto_minor_version_upgrade = true
# ---------------------------------------------------------------------------

resource "aws_mq_broker" "pass" {
  broker_name        = "regression-test-pass"
  engine_type        = "ActiveMQ"
  engine_version     = "5.17.6"
  host_instance_type = "mq.t3.micro"
  deployment_mode    = "SINGLE_INSTANCE"
  subnet_ids         = [var.private_subnet_ids[0]]
  security_groups    = [aws_security_group.mq.id]

  publicly_accessible        = false
  auto_minor_version_upgrade = true

  logs {
    general = true
    audit   = true
  }

  user {
    username       = "mqadmin"
    password       = "Ch@ngeMe2024!"
    console_access = true
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# MQ.2 — fail: audit = false
# ---------------------------------------------------------------------------

resource "aws_mq_broker" "audit_fail" {
  count = var.create_failing_resources ? 1 : 0

  broker_name        = "regression-test-audit-fail"
  engine_type        = "ActiveMQ"
  engine_version     = "5.17.6"
  host_instance_type = "mq.t3.micro"
  deployment_mode    = "SINGLE_INSTANCE"
  subnet_ids         = [var.private_subnet_ids[0]]
  security_groups    = [aws_security_group.mq.id]

  publicly_accessible        = false
  auto_minor_version_upgrade = true

  logs {
    general = true
    audit   = false # intentional violation
  }

  user {
    username = "mqadmin"
    password = "Ch@ngeMe2024!"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-audit-fail"
    compliance_test = "intentional_violation"
    controls        = "MQ.2"
  })
}

# ---------------------------------------------------------------------------
# MQ.1 — fail: auto_minor_version_upgrade = false
# ---------------------------------------------------------------------------

resource "aws_mq_broker" "upgrade_fail" {
  count = var.create_failing_resources ? 1 : 0

  broker_name        = "regression-test-upgrade-fail"
  engine_type        = "ActiveMQ"
  engine_version     = "5.17.6"
  host_instance_type = "mq.t3.micro"
  deployment_mode    = "SINGLE_INSTANCE"
  subnet_ids         = [var.private_subnet_ids[0]]
  security_groups    = [aws_security_group.mq.id]

  publicly_accessible        = false
  auto_minor_version_upgrade = false # intentional violation

  logs {
    general = true
    audit   = true
  }

  user {
    username = "mqadmin"
    password = "Ch@ngeMe2024!"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-upgrade-fail"
    compliance_test = "intentional_violation"
    controls        = "MQ.1"
  })
}
