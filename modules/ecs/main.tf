# ---------------------------------------------------------------------------
# modules/ecs/main.tf
#
# Security controls covered:
#   ECS.2  — ECS services should not have public IP addresses assigned automatically
#   ECS.3  — ECS task definitions should not share the host's process namespace
#   ECS.4  — ECS containers should run as non-privileged
#   ECS.5  — ECS containers should not have read/write access to the root filesystem
#   ECS.8  — Secrets should not be passed as container environment variables
#   ECS.9  — ECS task definitions should have a logging configuration
#   ECS.12 — ECS clusters should use Container Insights
#   ECS.20 — ECS task definitions should not run containers as root
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Shared — CloudWatch log group for ECS task logging
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/regression-test"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "/ecs/regression-test"
  })
}

# ---------------------------------------------------------------------------
# ECS.12 — ECS clusters should use Container Insights
#
# pass:          containerInsights = "enabled"
# insights_fail: containerInsights = "disabled"  (intentional_violation)
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "regression-test"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "regression-test"
  })
}

resource "aws_ecs_cluster" "insights_fail" {
  count = var.create_failing_resources ? 1 : 0
  name  = "regression-test-insights-fail"

  setting {
    name  = "containerInsights"
    value = "disabled" # intentional_violation: ECS.12
  }

  tags = merge(var.tags, {
    Name            = "regression-test-insights-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.12"
  })
}

# ---------------------------------------------------------------------------
# ECS.4 / ECS.5 / ECS.9 / ECS.20 — Task definition controls
#
# Shared locals keep the container definition DRY while each fail resource
# overrides exactly one field.
# ---------------------------------------------------------------------------

locals {
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
      "awslogs-region"        = "us-east-1"
      "awslogs-stream-prefix" = "web"
    }
  }

  secrets = [
    { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password" }
  ]

  port_mappings = [{ containerPort = 8080, protocol = "tcp" }]
}

# pass task definition — fully compliant web app container
resource "aws_ecs_task_definition" "pass" {
  family                   = "regression-test-pass"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = "nginx:1.25-alpine"
    essential              = true
    portMappings           = local.port_mappings
    privileged             = false
    readonlyRootFilesystem = true
    user                   = "1000"
    logConfiguration       = local.log_configuration
    environment            = []
    secrets                = local.secrets
  }])

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

# ECS.4 — privileged=true (intentional_violation)
resource "aws_ecs_task_definition" "privileged_fail" {
  count                    = var.create_failing_resources ? 1 : 0
  family                   = "regression-test-privileged-fail"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = "nginx:1.25-alpine"
    essential              = true
    portMappings           = local.port_mappings
    privileged             = true # intentional_violation: ECS.4
    readonlyRootFilesystem = true
    user                   = "1000"
    logConfiguration       = local.log_configuration
    environment            = []
    secrets                = local.secrets
  }])

  tags = merge(var.tags, {
    Name            = "regression-test-privileged-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.4"
  })
}

# ECS.5 — readonlyRootFilesystem=false (intentional_violation)
resource "aws_ecs_task_definition" "readonly_fail" {
  count                    = var.create_failing_resources ? 1 : 0
  family                   = "regression-test-readonly-fail"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = "nginx:1.25-alpine"
    essential              = true
    portMappings           = local.port_mappings
    privileged             = false
    readonlyRootFilesystem = false # intentional_violation: ECS.5
    user                   = "1000"
    logConfiguration       = local.log_configuration
    environment            = []
    secrets                = local.secrets
  }])

  tags = merge(var.tags, {
    Name            = "regression-test-readonly-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.5"
  })
}

# ECS.9 — logConfiguration omitted (intentional_violation)
resource "aws_ecs_task_definition" "logging_fail" {
  count                    = var.create_failing_resources ? 1 : 0
  family                   = "regression-test-logging-fail"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = "nginx:1.25-alpine"
    essential              = true
    portMappings           = local.port_mappings
    privileged             = false
    readonlyRootFilesystem = true
    user                   = "1000"
    # intentional_violation: ECS.9 — logConfiguration deliberately omitted
    environment = []
    secrets     = local.secrets
  }])

  tags = merge(var.tags, {
    Name            = "regression-test-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.9"
  })
}

# ECS.8 — secret passed as plaintext environment variable (intentional_violation)
resource "aws_ecs_task_definition" "secrets_fail" {
  count                    = var.create_failing_resources ? 1 : 0
  family                   = "regression-test-secrets-fail"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = "nginx:1.25-alpine"
    essential              = true
    portMappings           = local.port_mappings
    privileged             = false
    readonlyRootFilesystem = true
    user                   = "1000"
    logConfiguration       = local.log_configuration
    environment            = [{ name = "DB_PASSWORD", value = "plaintext-secret" }] # intentional_violation: ECS.8
    secrets                = []
  }])

  tags = merge(var.tags, {
    Name            = "regression-test-secrets-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.8"
  })
}

# ECS.3 — pidMode="host" shares host process namespace (intentional_violation)
resource "aws_ecs_task_definition" "pid_fail" {
  count                    = var.create_failing_resources ? 1 : 0
  family                   = "regression-test-pid-fail"
  requires_compatibilities = ["EC2"] # pidMode=host requires EC2 launch type
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn
  pid_mode                 = "host" # intentional_violation: ECS.3

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = "nginx:1.25-alpine"
    essential              = true
    portMappings           = local.port_mappings
    privileged             = false
    readonlyRootFilesystem = true
    user                   = "1000"
    logConfiguration       = local.log_configuration
    environment            = []
    secrets                = local.secrets
  }])

  tags = merge(var.tags, {
    Name            = "regression-test-pid-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.3"
  })
}

# ECS.20 — user="0" runs container as root (intentional_violation)
resource "aws_ecs_task_definition" "root_user_fail" {
  count                    = var.create_failing_resources ? 1 : 0
  family                   = "regression-test-root-user-fail"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = "nginx:1.25-alpine"
    essential              = true
    portMappings           = local.port_mappings
    privileged             = false
    readonlyRootFilesystem = true
    user                   = "0" # intentional_violation: ECS.20 — root user
    logConfiguration       = local.log_configuration
    environment            = []
    secrets                = local.secrets
  }])

  tags = merge(var.tags, {
    Name            = "regression-test-root-user-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.20"
  })
}

# ---------------------------------------------------------------------------
# ECS.2 — ECS services should not have public IP addresses assigned
#
# pass:        assign_public_ip = false
# public_fail: assign_public_ip = true  (intentional_violation)
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "pass" {
  name            = "regression-test-pass"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.pass.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }

  tags = merge(var.tags, {
    Name = "regression-test-pass"
  })
}

resource "aws_ecs_service" "public_fail" {
  count           = var.create_failing_resources ? 1 : 0
  name            = "regression-test-public-fail"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.pass.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = true # intentional_violation: ECS.2
  }

  tags = merge(var.tags, {
    Name            = "regression-test-public-fail"
    compliance_test = "intentional_violation"
    controls        = "ECS.2"
  })
}
