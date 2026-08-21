# ---------------------------------------------------------------------------
# modules/autoscaling-group/main.tf
#
# Security controls covered:
#   AutoScaling.1  — ASG attached to ELB should use ELB health check
#   AutoScaling.2  — ASG should cover multiple Availability Zones
#   AutoScaling.5  — Launch configurations should not assign public IPs
#   AutoScaling.9  — ASG should use EC2 launch templates (not launch configs)
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
# Shared security group
# ---------------------------------------------------------------------------

resource "aws_security_group" "asg" {
  name        = "asg-regression-test"
  description = "ASG regression test — allow egress only."
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "asg-regression-test"
  })
}

# ---------------------------------------------------------------------------
# Pass launch template (AutoScaling.9 — use launch templates)
# ---------------------------------------------------------------------------

resource "aws_launch_template" "pass" {
  name          = "asg-lt-pass"
  description   = "Compliant ASG launch template — no public IP, IMDSv2 required"
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
    security_groups             = [aws_security_group.asg.id]
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
      Name = "asg-lt-pass-instance"
    })
  }

  tags = merge(var.tags, {
    Name = "asg-lt-pass"
  })
}

# ---------------------------------------------------------------------------
# Pass ASG
#   AutoScaling.1  — health_check_type = "ELB"
#   AutoScaling.2  — vpc_zone_identifier spans all private subnets (multi-AZ)
#   AutoScaling.9  — uses launch_template block (not launch_configuration)
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "pass" {
  name                      = "asg-regression-test-pass"
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.pass.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "asg-regression-test-pass"
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = "regression-test"
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------------------
# Fail: AutoScaling.5 — launch configuration assigns public IP
# ---------------------------------------------------------------------------

resource "aws_launch_configuration" "public_ip_fail" {
  count = var.create_failing_resources ? 1 : 0

  name_prefix                 = "asg-lc-public-ip-fail-"
  image_id                    = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true # intentional violation
  enable_monitoring           = true
  security_groups             = [aws_security_group.asg.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Fail: AutoScaling.2 — single AZ only
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "single_az_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                      = "asg-single-az-fail"
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [var.private_subnet_ids[0]] # intentional violation: one subnet/AZ
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.pass.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "asg-single-az-fail"
    propagate_at_launch = true
  }

  tag {
    key                 = "compliance_test"
    value               = "intentional_violation"
    propagate_at_launch = false
  }

  tag {
    key                 = "controls"
    value               = "AutoScaling.2"
    propagate_at_launch = false
  }
}

# ---------------------------------------------------------------------------
# Fail: AutoScaling.1 — EC2 health check instead of ELB
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "ec2_healthcheck_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                      = "asg-ec2-hc-fail"
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2" # intentional violation
  health_check_grace_period = 300
  target_group_arns         = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.pass.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "asg-ec2-hc-fail"
    propagate_at_launch = true
  }

  tag {
    key                 = "compliance_test"
    value               = "intentional_violation"
    propagate_at_launch = false
  }

  tag {
    key                 = "controls"
    value               = "AutoScaling.1"
    propagate_at_launch = false
  }
}

# ---------------------------------------------------------------------------
# Fail: AutoScaling.9 — uses launch_configuration instead of launch_template
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "no_launch_template_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                      = "asg-no-lt-fail"
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [var.target_group_arn]
  launch_configuration      = aws_launch_configuration.public_ip_fail[0].name # intentional violation

  tag {
    key                 = "Name"
    value               = "asg-no-lt-fail"
    propagate_at_launch = true
  }

  tag {
    key                 = "compliance_test"
    value               = "intentional_violation"
    propagate_at_launch = false
  }

  tag {
    key                 = "controls"
    value               = "AutoScaling.9"
    propagate_at_launch = false
  }
}
