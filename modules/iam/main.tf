# ---------------------------------------------------------------------------
# modules/iam/main.tf
#
# Security controls covered:
#   IAM.1   — No admin privileges allowed by policies
#   IAM.2   — No policies attached directly to users (CIS-1.14)
#   IAM.7   — Strong password policy (CIS-1.7, CIS-1.8) [singleton toggle]
#   IAM.21  — No wildcard service actions in policies
#   CIS-1.16 — Support role exists
#   CIS-1.19 — IAM Access Analyzer enabled
#
# Shared IAM roles consumed by other service modules are also created here.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# IAM.1 — No admin privileges allowed by policies
# ---------------------------------------------------------------------------

# pass: tightly scoped S3 read/write on a specific bucket prefix
resource "aws_iam_policy" "pass" {
  name        = "iam1-pass-s3-scoped"
  description = "Scoped S3 read/write — compliant with IAM.1"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ScopedReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "arn:aws:s3:::my-app-data-bucket/uploads/*"
      },
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::my-app-data-bucket"
        Condition = {
          StringLike = { "s3:prefix" = ["uploads/*"] }
        }
      },
    ]
  })

  tags = var.tags
}

# fail: wildcard Action + Resource = admin privileges
# intentional_violation: Action = "*", Resource = "*"
resource "aws_iam_policy" "fail" {
  count = var.create_failing_resources ? 1 : 0

  name        = "iam1-fail-admin-wildcard"
  description = "Admin wildcard policy — intentional IAM.1 violation"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AdminWildcard"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "IAM.1"
  })
}

# ---------------------------------------------------------------------------
# IAM.21 — No wildcard service actions in policies
# ---------------------------------------------------------------------------

# pass: all EC2 actions explicitly named
resource "aws_iam_policy" "scoped_pass" {
  name        = "iam21-pass-ec2-scoped"
  description = "Explicit EC2 actions — compliant with IAM.21"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ScopedActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:DescribeTags",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

# fail: wildcard on an entire service
# intentional_violation: Action = "ec2:*"
resource "aws_iam_policy" "wildcard_fail" {
  count = var.create_failing_resources ? 1 : 0

  name        = "iam21-fail-ec2-wildcard"
  description = "EC2 service wildcard — intentional IAM.21 violation"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EC2Wildcard"
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "IAM.21"
  })
}

# ---------------------------------------------------------------------------
# IAM.2 / CIS-1.14 — No policies attached directly to users
# ---------------------------------------------------------------------------

# Shared policy attached to the group (used by both pass and fail paths)
resource "aws_iam_policy" "s3_read" {
  name        = "iam2-group-s3-readonly"
  description = "S3 read-only policy attached at group level"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3ReadOnly"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::my-app-data-bucket", "arn:aws:s3:::my-app-data-bucket/*"]
      },
    ]
  })

  tags = var.tags
}

# pass: user belongs to a group; policy is on the group, not the user
resource "aws_iam_user" "pass" {
  name = "iam2-pass-user"
  path = "/"
  tags = var.tags
}

resource "aws_iam_group" "pass" {
  name = "iam2-pass-group"
  path = "/"
}

resource "aws_iam_group_membership" "pass" {
  name  = "iam2-pass-group-membership"
  group = aws_iam_group.pass.name
  users = [aws_iam_user.pass.name]
}

resource "aws_iam_group_policy_attachment" "pass" {
  group      = aws_iam_group.pass.name
  policy_arn = aws_iam_policy.s3_read.arn
}

# fail: policy attached directly to a user
# intentional_violation: aws_iam_user_policy_attachment (direct user attachment)
resource "aws_iam_user" "fail" {
  count = var.create_failing_resources ? 1 : 0

  name = "iam2-fail-user"
  path = "/"

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "IAM.2,CIS-1.14"
  })
}

resource "aws_iam_user_policy_attachment" "fail" {
  count = var.create_failing_resources ? 1 : 0

  user       = aws_iam_user.fail[0].name
  policy_arn = aws_iam_policy.s3_read.arn
}

# ---------------------------------------------------------------------------
# IAM.7 / CIS-1.7 / CIS-1.8 — Strong password policy (singleton toggle)
# ---------------------------------------------------------------------------

resource "aws_iam_account_password_policy" "this" {
  # intentional_violation (when create_failing_resources = true):
  #   minimum_password_length = 6, password_reuse_prevention = 1
  minimum_password_length        = var.create_failing_resources ? 6 : 14
  password_reuse_prevention      = var.create_failing_resources ? 1 : 24
  require_uppercase_characters   = var.create_failing_resources ? false : true
  require_lowercase_characters   = var.create_failing_resources ? false : true
  require_symbols                = var.create_failing_resources ? false : true
  require_numbers                = var.create_failing_resources ? false : true
  allow_users_to_change_password = true
  max_password_age               = var.create_failing_resources ? 0 : 90
  hard_expiry                    = false
}

# ---------------------------------------------------------------------------
# CIS-1.16 — Support role exists (no fail variant; absence = fail)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "support_trust" {
  statement {
    sid     = "SupportServiceTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["support.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "support_pass" {
  name               = "cis116-support-role"
  description        = "Break-glass support role — satisfies CIS-1.16"
  assume_role_policy = data.aws_iam_policy_document.support_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "support_access" {
  role       = aws_iam_role.support_pass.name
  policy_arn = "arn:aws:iam::aws:policy/AWSSupportAccess"
}

# ---------------------------------------------------------------------------
# CIS-1.19 — IAM Access Analyzer enabled (no fail variant; absence = fail)
# ---------------------------------------------------------------------------

resource "aws_accessanalyzer_analyzer" "pass" {
  analyzer_name = "account-analyzer"
  type          = "ACCOUNT"

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Shared: EC2 instance profile role (consumed by ec2, eks, ecs modules)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_instance_pass" {
  name               = "shared-ec2-instance-role"
  description        = "EC2 instance role with SSM access for all pass EC2 resources"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_instance_pass.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_pass" {
  name = "shared-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_pass.name
  tags = var.tags
}

# ---------------------------------------------------------------------------
# Shared: RDS enhanced monitoring role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "rds_monitoring_trust" {
  statement {
    sid     = "RDSMonitoringTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "shared-rds-enhanced-monitoring"
  description        = "Allows RDS to push enhanced monitoring metrics to CloudWatch"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---------------------------------------------------------------------------
# Shared: EKS cluster role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_cluster_trust" {
  statement {
    sid     = "EKSClusterTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "shared-eks-cluster-role"
  description        = "EKS cluster service role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------------------------
# Shared: EKS node group role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "eks_node" {
  name               = "shared-eks-node-role"
  description        = "EKS managed node group role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json # same trust as EC2
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------------------------------------------------------------------------
# Shared: ECS task execution role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_trust" {
  statement {
    sid     = "ECSTasksTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "shared-ecs-task-execution-role"
  description        = "ECS task execution role — allows pulling images and writing logs"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# Shared: Lambda execution role (VPC-capable)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    sid     = "LambdaTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "shared-lambda-execution-role"
  description        = "Lambda execution role with VPC ENI and CloudWatch Logs access"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ---------------------------------------------------------------------------
# Shared: CloudTrail → CloudWatch Logs role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cloudtrail_trust" {
  statement {
    sid     = "CloudTrailTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_logs" {
  statement {
    sid    = "CloudTrailCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*"]
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name               = "shared-cloudtrail-cloudwatch-role"
  description        = "Allows CloudTrail to deliver logs to CloudWatch Logs"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name   = "cloudtrail-cloudwatch-logs-inline"
  role   = aws_iam_role.cloudtrail_cloudwatch.id
  policy = data.aws_iam_policy_document.cloudtrail_logs.json
}
