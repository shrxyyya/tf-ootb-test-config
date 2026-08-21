# ---------------------------------------------------------------------------
# modules/eks/main.tf
#
# Security controls covered:
#   EKS.1 — eks-cluster-endpoints-restrict-public-access
#   EKS.2 — eks-cluster-supported-k8s-version-check
#   EKS.3 — eks-cluster-encrypted-kubernetes-secrets
#   EKS.8 — eks-cluster-audit-logging-enabled
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Shared infrastructure — always created
# ---------------------------------------------------------------------------

resource "aws_security_group" "eks_cluster" {
  name        = "eks-cluster-sg"
  description = "EKS control plane — accepts HTTPS from private subnets only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = data.aws_subnet.private[*].cidr_block
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "eks-cluster-sg"
  })
}

data "aws_subnet" "private" {
  count = length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

resource "aws_security_group" "eks_nodes" {
  name        = "eks-nodes-sg"
  description = "EKS managed nodes — intra-cluster and ephemeral return traffic"
  vpc_id      = var.vpc_id

  ingress {
    description     = "All traffic from cluster control plane SG"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  ingress {
    description = "Node-to-node ephemeral ports"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "eks-nodes-sg"
  })
}

resource "aws_cloudwatch_log_group" "eks_pass" {
  name              = "/aws/eks/regression-test-pass/cluster"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# ---------------------------------------------------------------------------
# EKS.1 — eks-cluster-endpoints-restrict-public-access
#
# pass: endpoint_public_access = false, endpoint_private_access = true
# fail: endpoint_public_access = true  (intentional violation)
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "pass" {
  name     = "regression-test-pass"
  version  = "1.30"
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_key_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.eks_pass]

  tags = var.tags
}

# fail: endpoint_public_access = true, endpoint_private_access = true
# intentional_violation: endpoint_public_access = true
resource "aws_eks_cluster" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  name     = "regression-test-public-fail"
  version  = "1.30"
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_key_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.eks_public_fail]

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EKS.1"
  })
}

resource "aws_cloudwatch_log_group" "eks_public_fail" {
  count             = var.create_failing_resources ? 1 : 0
  name              = "/aws/eks/regression-test-public-fail/cluster"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# ---------------------------------------------------------------------------
# EKS.3 — eks-cluster-encrypted-kubernetes-secrets
#
# fail: no encryption_config block (intentional violation)
# ---------------------------------------------------------------------------

# fail: encryption_config omitted
# intentional_violation: no encryption_config
resource "aws_eks_cluster" "secrets_fail" {
  count = var.create_failing_resources ? 1 : 0

  name     = "regression-test-secrets-fail"
  version  = "1.30"
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # ponytail: encryption_config intentionally absent — that IS the violation
  depends_on = [aws_cloudwatch_log_group.eks_secrets_fail]

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EKS.3"
  })
}

resource "aws_cloudwatch_log_group" "eks_secrets_fail" {
  count             = var.create_failing_resources ? 1 : 0
  name              = "/aws/eks/regression-test-secrets-fail/cluster"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# ---------------------------------------------------------------------------
# EKS.8 — eks-cluster-audit-logging-enabled
#
# fail: enabled_cluster_log_types = [] (intentional violation)
# ---------------------------------------------------------------------------

# fail: no log types enabled
# intentional_violation: enabled_cluster_log_types = []
resource "aws_eks_cluster" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  name     = "regression-test-logging-fail"
  version  = "1.30"
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = []

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_key_arn
    }
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EKS.8"
  })
}

# ---------------------------------------------------------------------------
# EKS.2 — eks-cluster-supported-k8s-version-check
#
# fail: version = "1.24" (EOL, intentional violation)
# ---------------------------------------------------------------------------

# fail: Kubernetes 1.24 is end-of-life
# intentional_violation: version = "1.24"
resource "aws_eks_cluster" "version_fail" {
  count = var.create_failing_resources ? 1 : 0

  name     = "regression-test-version-fail"
  version  = "1.24"
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_key_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.eks_version_fail]

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "EKS.2"
  })
}

resource "aws_cloudwatch_log_group" "eks_version_fail" {
  count             = var.create_failing_resources ? 1 : 0
  name              = "/aws/eks/regression-test-version-fail/cluster"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Node group — pass cluster only
# ---------------------------------------------------------------------------

resource "aws_eks_node_group" "pass" {
  cluster_name    = aws_eks_cluster.pass.name
  node_group_name = "regression-test-pass-nodes"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.medium"]
  ami_type        = "AL2_x86_64"
  disk_size       = 20

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, {
    Name = "eks-node-group-pass"
  })
}
