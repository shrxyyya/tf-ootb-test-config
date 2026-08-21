terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Shared IAM role for SageMaker
# ---------------------------------------------------------------------------

resource "aws_iam_role" "sagemaker" {
  name = "regression-test-sagemaker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "regression-test-sagemaker" })
}

resource "aws_iam_role_policy_attachment" "sagemaker" {
  role       = aws_iam_role.sagemaker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# ---------------------------------------------------------------------------
# Shared security group — no inbound, HTTPS outbound only
# ---------------------------------------------------------------------------

resource "aws_security_group" "sagemaker" {
  name        = "regression-test-sagemaker"
  description = "SageMaker notebook — no inbound, HTTPS egress only."
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS egress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "regression-test-sagemaker" })
}

# ---------------------------------------------------------------------------
# SageMaker.1 — sagemaker-notebook-no-direct-internet-access
# SageMaker.2 — sagemaker-notebook-instances-should-be-launched-in-a-custom-vpc
# SageMaker.3 — sagemaker-notebook-instance-root-access-check
# Pass: direct_internet_access = Disabled, root_access = Disabled, subnet set
# ---------------------------------------------------------------------------

resource "aws_sagemaker_notebook_instance" "pass" {
  name                   = "regression-test-pass"
  role_arn               = aws_iam_role.sagemaker.arn
  instance_type          = "ml.t3.medium"
  direct_internet_access = "Disabled"
  root_access            = "Disabled"
  subnet_id              = var.private_subnet_ids[0]
  security_groups        = [aws_security_group.sagemaker.id]
  kms_key_id             = var.kms_key_arn
  platform_identifier    = "notebook-al2-v2"

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# SageMaker.1 — fail: direct_internet_access = Enabled
# ---------------------------------------------------------------------------

resource "aws_sagemaker_notebook_instance" "internet_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                   = "regression-test-internet-fail"
  role_arn               = aws_iam_role.sagemaker.arn
  instance_type          = "ml.t3.medium"
  direct_internet_access = "Enabled" # intentional violation
  root_access            = "Disabled"
  subnet_id              = var.private_subnet_ids[0]
  security_groups        = [aws_security_group.sagemaker.id]
  kms_key_id             = var.kms_key_arn
  platform_identifier    = "notebook-al2-v2"

  tags = merge(var.tags, {
    Name            = "regression-test-internet-fail"
    compliance_test = "intentional_violation"
    controls        = "SageMaker.1"
  })
}

# ---------------------------------------------------------------------------
# SageMaker.3 — fail: root_access = Enabled
# ---------------------------------------------------------------------------

resource "aws_sagemaker_notebook_instance" "root_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                   = "regression-test-root-fail"
  role_arn               = aws_iam_role.sagemaker.arn
  instance_type          = "ml.t3.medium"
  direct_internet_access = "Disabled"
  root_access            = "Enabled" # intentional violation
  subnet_id              = var.private_subnet_ids[0]
  security_groups        = [aws_security_group.sagemaker.id]
  kms_key_id             = var.kms_key_arn
  platform_identifier    = "notebook-al2-v2"

  tags = merge(var.tags, {
    Name            = "regression-test-root-fail"
    compliance_test = "intentional_violation"
    controls        = "SageMaker.3"
  })
}

# ---------------------------------------------------------------------------
# SageMaker.2 — fail: no subnet_id / no VPC config
# ---------------------------------------------------------------------------

resource "aws_sagemaker_notebook_instance" "novpc_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                   = "regression-test-novpc-fail"
  role_arn               = aws_iam_role.sagemaker.arn
  instance_type          = "ml.t3.medium"
  direct_internet_access = "Disabled"
  root_access            = "Disabled"
  # subnet_id intentionally omitted — intentional violation (no custom VPC)
  kms_key_id          = var.kms_key_arn
  platform_identifier = "notebook-al2-v2"

  tags = merge(var.tags, {
    Name            = "regression-test-novpc-fail"
    compliance_test = "intentional_violation"
    controls        = "SageMaker.2"
  })
}

# ---------------------------------------------------------------------------
# SageMaker.5 — sagemaker-models-should-block-inbound-traffic
# Pass: enable_network_isolation = true, vpc_config set
# ---------------------------------------------------------------------------

resource "aws_sagemaker_model" "pass" {
  name               = "regression-test-pass"
  execution_role_arn = aws_iam_role.sagemaker.arn

  enable_network_isolation = true

  primary_container {
    image          = "763104351884.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/pytorch-inference:2.0.1-cpu-py310"
    model_data_url = "s3://sagemaker-sample-files/models/object_detection/ssd/model.tar.gz"
  }

  vpc_config {
    subnets            = var.private_subnet_ids
    security_group_ids = [aws_security_group.sagemaker.id]
  }

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# SageMaker.5 — fail: enable_network_isolation = false
# ---------------------------------------------------------------------------

resource "aws_sagemaker_model" "isolation_fail" {
  count = var.create_failing_resources ? 1 : 0

  name               = "regression-test-isolation-fail"
  execution_role_arn = aws_iam_role.sagemaker.arn

  enable_network_isolation = false # intentional violation

  primary_container {
    image          = "763104351884.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/pytorch-inference:2.0.1-cpu-py310"
    model_data_url = "s3://sagemaker-sample-files/models/object_detection/ssd/model.tar.gz"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-isolation-fail"
    compliance_test = "intentional_violation"
    controls        = "SageMaker.5"
  })
}

# ---------------------------------------------------------------------------
# SageMaker.4 — sagemaker-endpoint-config-prod-instance-count-check
# Pass: initial_instance_count = 2
# ---------------------------------------------------------------------------

resource "aws_sagemaker_endpoint_configuration" "pass" {
  name = "regression-test-pass"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.pass.name
    initial_instance_count = 2
    instance_type          = "ml.t2.medium"
    initial_variant_weight = 1
  }

  kms_key_arn = var.kms_key_arn

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# SageMaker.4 — fail: initial_instance_count = 1
# ---------------------------------------------------------------------------

resource "aws_sagemaker_endpoint_configuration" "single_instance_fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "regression-test-single-fail"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.pass.name
    initial_instance_count = 1 # intentional violation
    instance_type          = "ml.t2.medium"
    initial_variant_weight = 1
  }

  tags = merge(var.tags, {
    Name            = "regression-test-single-fail"
    compliance_test = "intentional_violation"
    controls        = "SageMaker.4"
  })
}
