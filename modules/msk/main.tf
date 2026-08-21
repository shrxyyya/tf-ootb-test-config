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

resource "aws_security_group" "msk" {
  name        = "msk-regression-test"
  description = "Allow Kafka traffic on ports 9092-9096 from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "Kafka plaintext + TLS from private subnets"
    from_port   = 9092
    to_port     = 9096
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
    Name = "msk-regression-test"
  })
}

resource "aws_msk_configuration" "main" {
  name           = "regression-test"
  kafka_versions = ["3.6.0"]
  description    = "MSK configuration for regression test workloads."

  server_properties = <<-PROPS
    auto.create.topics.enable=false
    delete.topic.enable=true
    log.retention.hours=168
    min.insync.replicas=2
    default.replication.factor=3
    num.partitions=6
  PROPS
}

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/regression-test"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "msk-regression-test"
  })
}

# ---------------------------------------------------------------------------
# Pass cluster — fully compliant, production-realistic
# ---------------------------------------------------------------------------

resource "aws_msk_cluster" "pass" {
  cluster_name           = "regression-test-pass"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = var.private_subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = 20
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  enhanced_monitoring = "PER_TOPIC_PER_BROKER"

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ---------------------------------------------------------------------------
# MSK.1 — msk-in-cluster-node-require-encrypted-in-transit
# fail: client_broker = "PLAINTEXT"
# ---------------------------------------------------------------------------

resource "aws_msk_cluster" "transit_fail" {
  count = var.create_failing_resources ? 1 : 0

  cluster_name           = "regression-test-transit-fail"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = var.private_subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = 20
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT" # intentional violation
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  enhanced_monitoring = "PER_TOPIC_PER_BROKER"

  tags = merge(var.tags, {
    Name            = "regression-test-transit-fail"
    compliance_test = "intentional_violation"
    controls        = "MSK.1"
  })
}

# ---------------------------------------------------------------------------
# MSK.2 — msk-connect-connector-encrypted
#
# MSK Connect requires a running MSK cluster, a deployed connector plugin
# (S3 artifact), and a VPC worker configuration. Provisioning the plugin
# alone costs real money and takes several minutes. This control is
# therefore gated on var.create_msk_connect (default = false).
# Enable only in dedicated MSK Connect test runs with a pre-built plugin.
# ---------------------------------------------------------------------------

# ponytail: MSK Connect resources omitted by default; enable via create_msk_connect=true when a plugin S3 artifact and worker config are ready.
