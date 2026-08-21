# ---------------------------------------------------------------------------
# modules/ec2/main.tf
#
# Security controls covered:
#   EC2.3   — Attached EBS volumes encrypted at rest
#   EC2.2   / CIS-5.5  — Default security group has no traffic rules (singleton toggle)
#   EC2.6   / CIS-3.7  — VPC flow logging enabled (pass only; absence = fail)
#   EC2.7   / CIS-5.1.1 — EBS encryption by default (singleton toggle)
#   EC2.8   / CIS-5.7  — IMDSv2 required on EC2 instances
#   EC2.9              — EC2 instances should not have a public IP
#   EC2.15             — Subnets should not auto-assign public IPs
#   EC2.19  / CIS-5.3 / CIS-5.4 — Security group restricts common admin ports
#   EC2.21  / CIS-5.2  — Network ACL denies SSH/RDP from 0.0.0.0/0
#   EC2.23             — Transit gateway auto-accept shared attachments disabled
#   EC2.25  / EC2.170  — Launch template: no public IP, IMDSv2 required
# ---------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# EC2.7 / CIS-5.1.1 — EBS encryption by default (singleton toggle)
#
# intentional_violation (when create_failing_resources = true): enabled = false
# ---------------------------------------------------------------------------

resource "aws_ebs_encryption_by_default" "this" {
  enabled = var.create_failing_resources ? false : true
}

# ---------------------------------------------------------------------------
# EC2.8 / CIS-5.7 — IMDSv2 required
# ---------------------------------------------------------------------------

# pass: http_tokens = "required"
resource "aws_instance" "app_pass" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.medium"
  subnet_id              = var.private_subnet_ids[0]
  iam_instance_profile   = var.instance_profile_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.app_pass.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "ec2-imdsv2-pass"
  })
}

# fail: http_tokens = "optional"
# intentional_violation: http_tokens = "optional"
resource "aws_instance" "app_fail" {
  count = var.create_failing_resources ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.medium"
  subnet_id              = var.private_subnet_ids[0]
  iam_instance_profile   = var.instance_profile_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.app_pass.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name            = "ec2-imdsv2-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.8,CIS-5.7"
  })
}

# ---------------------------------------------------------------------------
# EC2.9 — Instances should not have a public IP
# ---------------------------------------------------------------------------

# pass: associate_public_ip_address = false
resource "aws_instance" "private_pass" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.private_subnet_ids[0]
  associate_public_ip_address = false
  iam_instance_profile        = var.instance_profile_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.app_pass.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "ec2-no-public-ip-pass"
  })
}

# fail: associate_public_ip_address = true
# intentional_violation: associate_public_ip_address = true
resource "aws_instance" "public_fail" {
  count = var.create_failing_resources ? 1 : 0

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.app_pass.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name            = "ec2-public-ip-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.9"
  })
}

# ---------------------------------------------------------------------------
# EC2.2 / CIS-5.5 — Default security group has no ingress or egress rules
#
# Singleton-style: only one default SG exists per VPC.
# When create_failing_resources = true, the default SG is NOT managed here,
# leaving AWS's default rules (allow-all inbound from same SG, allow-all
# outbound) in place — that is the intentional violation.
# When create_failing_resources = false, we take ownership and remove all rules.
# ---------------------------------------------------------------------------

resource "aws_default_security_group" "pass" {
  count  = var.create_failing_resources ? 0 : 1
  vpc_id = var.vpc_id

  # No ingress or egress blocks = no rules

  tags = merge(var.tags, {
    Name = "default-sg-locked-down"
  })
}

# ---------------------------------------------------------------------------
# EC2.19 / CIS-5.3 / CIS-5.4 — Security group restricts common admin ports
# ---------------------------------------------------------------------------

# pass: allows 443 inbound, 80 redirect inbound, full egress; no 22/3389
resource "aws_security_group" "app_pass" {
  name        = "ec2-app-sg-pass"
  description = "Web application SG - no SSH/RDP ingress"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP redirect from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "ec2-app-sg-pass"
  })
}

# fail: identical but adds SSH ingress from 0.0.0.0/0
# intentional_violation: ingress port 22 from 0.0.0.0/0
resource "aws_security_group" "app_fail" {
  count = var.create_failing_resources ? 1 : 0

  name        = "ec2-app-sg-fail"
  description = "Web application SG with SSH open - intentional violation"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP redirect from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from internet - intentional violation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name            = "ec2-app-sg-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.19,CIS-5.3,CIS-5.4"
  })
}

# ---------------------------------------------------------------------------
# EC2.15 — Subnets should not auto-assign public IPs
# Dedicated test subnets (separate from root networking subnets)
# ---------------------------------------------------------------------------

# pass: map_public_ip_on_launch = false
resource "aws_subnet" "test_pass" {
  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.201.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "ec2-subnet-no-autoip-pass"
  })
}

# fail: map_public_ip_on_launch = true
# intentional_violation: map_public_ip_on_launch = true
resource "aws_subnet" "test_fail" {
  count = var.create_failing_resources ? 1 : 0

  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.202.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name            = "ec2-subnet-autoip-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.15"
  })
}

# ---------------------------------------------------------------------------
# EC2.21 / CIS-5.2 — Network ACL denies SSH/RDP from 0.0.0.0/0
# ---------------------------------------------------------------------------

# pass: explicit deny on 22 and 3389, then allow necessary traffic
resource "aws_network_acl" "pass" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.test_pass.id]

  tags = merge(var.tags, {
    Name = "ec2-nacl-pass"
  })
}

resource "aws_network_acl_rule" "pass_deny_ssh" {
  network_acl_id = aws_network_acl.pass.id
  rule_number    = 90
  protocol       = "tcp"
  rule_action    = "deny"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "pass_deny_rdp" {
  network_acl_id = aws_network_acl.pass.id
  rule_number    = 91
  protocol       = "tcp"
  rule_action    = "deny"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 3389
  to_port        = 3389
}

resource "aws_network_acl_rule" "pass_allow_https" {
  network_acl_id = aws_network_acl.pass.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "pass_allow_http" {
  network_acl_id = aws_network_acl.pass.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "pass_allow_ephemeral" {
  network_acl_id = aws_network_acl.pass.id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "pass_egress_all" {
  network_acl_id = aws_network_acl.pass.id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
}

# fail: only allow rules, no deny on 22/3389
# intentional_violation: no deny rules for SSH/RDP ingress
resource "aws_network_acl" "fail" {
  count      = var.create_failing_resources ? 1 : 0
  vpc_id     = var.vpc_id
  subnet_ids = []

  tags = merge(var.tags, {
    Name            = "ec2-nacl-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.21,CIS-5.2"
  })
}

resource "aws_network_acl_rule" "fail_allow_https" {
  count          = var.create_failing_resources ? 1 : 0
  network_acl_id = aws_network_acl.fail[0].id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "fail_allow_http" {
  count          = var.create_failing_resources ? 1 : 0
  network_acl_id = aws_network_acl.fail[0].id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "fail_allow_ephemeral" {
  count          = var.create_failing_resources ? 1 : 0
  network_acl_id = aws_network_acl.fail[0].id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "fail_egress_all" {
  count          = var.create_failing_resources ? 1 : 0
  network_acl_id = aws_network_acl.fail[0].id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# EC2.6 / CIS-3.7 — VPC flow logging enabled
#
# No fail variant: absence of a flow log = fail. The pass resource proves
# that detection policies do not fire when flow logs exist.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 90

  tags = var.tags
}

data "aws_iam_policy_document" "flow_log_trust" {
  statement {
    sid     = "FlowLogsTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_log_write" {
  statement {
    sid    = "FlowLogsCloudWatch"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "flow_log" {
  name               = "ec2-vpc-flow-log-role"
  description        = "Allows VPC Flow Logs to write to CloudWatch Logs"
  assume_role_policy = data.aws_iam_policy_document.flow_log_trust.json
  path               = "/"

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_log" {
  name   = "vpc-flow-log-cloudwatch-inline"
  role   = aws_iam_role.flow_log.id
  policy = data.aws_iam_policy_document.flow_log_write.json
}

resource "aws_flow_log" "pass" {
  vpc_id                   = var.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_log.arn
  max_aggregation_interval = 60

  tags = merge(var.tags, {
    Name = "vpc-flow-log-pass"
  })
}

# ---------------------------------------------------------------------------
# EC2.25 / EC2.170 — Launch template: no public IP, IMDSv2 required
# ---------------------------------------------------------------------------

# pass: no public IP, http_tokens = "required"
resource "aws_launch_template" "pass" {
  name          = "ec2-lt-pass"
  description   = "Production launch template — no public IP, IMDSv2 required"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium"

  iam_instance_profile {
    name = var.instance_profile_name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_pass.id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "ec2-lt-pass-instance"
    })
  }

  tags = merge(var.tags, {
    Name = "ec2-lt-pass"
  })
}

# fail: public IP enabled, http_tokens = "optional"
# intentional_violation: associate_public_ip_address = true, http_tokens = "optional"
resource "aws_launch_template" "fail" {
  count = var.create_failing_resources ? 1 : 0

  name          = "ec2-lt-fail"
  description   = "Launch template with public IP and IMDSv1 — intentional violation"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium"

  iam_instance_profile {
    name = var.instance_profile_name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_pass.id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "ec2-lt-fail-instance"
    })
  }

  tags = merge(var.tags, {
    Name            = "ec2-lt-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.25,EC2.170"
  })
}

# ---------------------------------------------------------------------------
# EC2.23 — Transit gateway auto-accept shared attachments disabled
# ---------------------------------------------------------------------------

# pass: auto_accept_shared_attachments = "disable"
resource "aws_ec2_transit_gateway" "pass" {
  description                     = "Production transit gateway — auto-accept disabled"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, {
    Name = "ec2-tgw-pass"
  })
}

# fail: auto_accept_shared_attachments = "enable"
# intentional_violation: auto_accept_shared_attachments = "enable"
resource "aws_ec2_transit_gateway" "fail" {
  count = var.create_failing_resources ? 1 : 0

  description                     = "Transit gateway with auto-accept enabled — intentional violation"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, {
    Name            = "ec2-tgw-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.23"
  })
}

# ---------------------------------------------------------------------------
# EC2.3 — Attached EBS volumes encrypted at rest
# ---------------------------------------------------------------------------

# pass: encrypted = true with KMS key
resource "aws_ebs_volume" "pass" {
  availability_zone = var.availability_zones[0]
  size              = 20
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "ec2-ebs-encrypted-pass"
  })
}

# fail: encrypted = false
# intentional_violation: encrypted = false
resource "aws_ebs_volume" "fail" {
  count = var.create_failing_resources ? 1 : 0

  availability_zone = var.availability_zones[0]
  size              = 20
  type              = "gp3"
  encrypted         = false

  tags = merge(var.tags, {
    Name            = "ec2-ebs-unencrypted-fail"
    compliance_test = "intentional_violation"
    controls        = "EC2.3"
  })
}
