terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Shared security group for Redshift Serverless workgroups
# ---------------------------------------------------------------------------

resource "aws_security_group" "redshift_serverless" {
  name        = "regression-test-redshift-serverless"
  description = "Allow Redshift traffic on port 5439 from private subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "Redshift from private subnets"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "regression-test-redshift-serverless" })
}

# ---------------------------------------------------------------------------
# RedshiftServerless.1 + .3 + .5 + .6 — pass namespace + workgroup
# Pass: admin_username != "admin", log_exports set,
#       enhanced_vpc_routing = true, publicly_accessible = false
# ---------------------------------------------------------------------------

resource "aws_redshiftserverless_namespace" "pass" {
  namespace_name      = "regression-test-pass"
  admin_username      = "clusteradmin" # NOT admin/awsuser — satisfies RedshiftServerless.5
  admin_user_password = "Ch@ngeMe2024!"
  db_name             = "appdb"
  kms_key_id          = var.kms_key_arn

  log_exports = ["userlog", "connectionlog", "useractivitylog"] # satisfies RedshiftServerless.6

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

resource "aws_redshiftserverless_workgroup" "pass" {
  namespace_name = aws_redshiftserverless_namespace.pass.namespace_name
  workgroup_name = "regression-test-pass"
  base_capacity  = 8

  enhanced_vpc_routing = true  # satisfies RedshiftServerless.3
  publicly_accessible  = false # satisfies RedshiftServerless.1

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.redshift_serverless.id]

  tags = merge(var.tags, { Name = "regression-test-pass" })
}

# ---------------------------------------------------------------------------
# RedshiftServerless.1 + .3 — fail: publicly_accessible = true,
#                               enhanced_vpc_routing = false
# ---------------------------------------------------------------------------

resource "aws_redshiftserverless_namespace" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  namespace_name      = "regression-test-public-fail"
  admin_username      = "clusteradmin"
  admin_user_password = "Ch@ngeMe2024!"
  db_name             = "appdb"
}

resource "aws_redshiftserverless_workgroup" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  namespace_name = aws_redshiftserverless_namespace.public_fail[0].namespace_name
  workgroup_name = "regression-test-public-fail"
  base_capacity  = 8

  enhanced_vpc_routing = false # intentional violation
  publicly_accessible  = true  # intentional violation

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.redshift_serverless.id]

  tags = merge(var.tags, {
    Name            = "regression-test-public-fail"
    compliance_test = "intentional_violation"
    controls        = "RedshiftServerless.1,RedshiftServerless.3"
  })
}

# ---------------------------------------------------------------------------
# RedshiftServerless.5 — fail: admin_username = "admin" (default username)
# ---------------------------------------------------------------------------

resource "aws_redshiftserverless_namespace" "admin_fail" {
  count = var.create_failing_resources ? 1 : 0

  namespace_name      = "regression-test-admin-fail"
  admin_username      = "admin" # intentional violation — default username
  admin_user_password = "Ch@ngeMe2024!"
  db_name             = "appdb"

  tags = merge(var.tags, {
    Name            = "regression-test-admin-fail"
    compliance_test = "intentional_violation"
    controls        = "RedshiftServerless.5"
  })
}

# ---------------------------------------------------------------------------
# RedshiftServerless.6 — fail: log_exports = [] (no log exports)
# ---------------------------------------------------------------------------

resource "aws_redshiftserverless_namespace" "nologs_fail" {
  count = var.create_failing_resources ? 1 : 0

  namespace_name      = "regression-test-nologs-fail"
  admin_username      = "clusteradmin"
  admin_user_password = "Ch@ngeMe2024!"
  db_name             = "appdb"
  log_exports         = [] # intentional violation — no logs exported

  tags = merge(var.tags, {
    Name            = "regression-test-nologs-fail"
    compliance_test = "intentional_violation"
    controls        = "RedshiftServerless.6"
  })
}
