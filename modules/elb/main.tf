# ---------------------------------------------------------------------------
# modules/elb/main.tf
#
# Security controls covered:
#   ELB.1  — HTTP listener redirects to HTTPS
#   ELB.4  — ALB drops invalid HTTP header fields
#   ELB.5  — ALB access logging enabled
#   ELB.6  — ALB deletion protection enabled
#   ELB.12 — ALB desync mitigation mode (defensive, not monitor)
#   ELB.13 — ALB spans multiple Availability Zones
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Shared infrastructure
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "alb-regression-test"
  description = "Allow HTTP/HTTPS inbound; all outbound for regression ALB."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "alb-regression-test"
  })
}

resource "aws_lb_target_group" "app" {
  name        = "regression-app-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "regression-app-tg"
  })
}

# ACM self-signed certificate — used by the HTTPS listener (ELB.1)
resource "aws_acm_certificate" "self_signed" {
  domain_name       = "regression-test.internal"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "regression-test-self-signed"
  })
}

# ---------------------------------------------------------------------------
# ELB.4 / ELB.5 / ELB.6 / ELB.12 / ELB.13 — Pass ALB
#
# Fully compliant baseline. All fail variants below deviate from exactly
# one attribute of this resource.
# ---------------------------------------------------------------------------

resource "aws_lb" "pass" {
  name                       = "regression-alb-pass"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  enable_http2               = true
  idle_timeout               = 60
  desync_mitigation_mode     = "defensive"

  access_logs {
    bucket  = var.logs_bucket_id
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "regression-alb-pass"
  })
}

# ---------------------------------------------------------------------------
# ELB.1 — HTTP listener must redirect to HTTPS
# ---------------------------------------------------------------------------

# Pass: HTTPS listener (terminates TLS, forwards to target group)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.pass.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.self_signed.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, {
    Name = "regression-alb-https"
  })
}

# Pass: HTTP listener redirects to HTTPS (HTTP_301)
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.pass.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(var.tags, {
    Name = "regression-alb-http-redirect"
  })
}

# Fail: HTTP listener forwards directly (no redirect) — violates ELB.1
resource "aws_lb_listener" "http_forward_fail" {
  count = var.create_failing_resources ? 1 : 0

  load_balancer_arn = aws_lb.pass.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, {
    Name            = "regression-alb-http-forward-fail"
    compliance_test = "intentional_violation"
    controls        = "ELB.1"
  })
}

# ---------------------------------------------------------------------------
# ELB.4 — drop_invalid_header_fields must be true
# ---------------------------------------------------------------------------

resource "aws_lb" "headers_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                       = "regression-alb-headers-fail"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = false # intentional violation
  enable_deletion_protection = true
  enable_http2               = true
  idle_timeout               = 60
  desync_mitigation_mode     = "defensive"

  access_logs {
    bucket  = var.logs_bucket_id
    enabled = true
  }

  tags = merge(var.tags, {
    Name            = "regression-alb-headers-fail"
    compliance_test = "intentional_violation"
    controls        = "ELB.4"
  })
}

# ---------------------------------------------------------------------------
# ELB.5 — access logging must be enabled
# ---------------------------------------------------------------------------

resource "aws_lb" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                       = "regression-alb-logging-fail"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  enable_http2               = true
  idle_timeout               = 60
  desync_mitigation_mode     = "defensive"

  access_logs {
    bucket  = var.logs_bucket_id
    enabled = false # intentional violation
  }

  tags = merge(var.tags, {
    Name            = "regression-alb-logging-fail"
    compliance_test = "intentional_violation"
    controls        = "ELB.5"
  })
}

# ---------------------------------------------------------------------------
# ELB.6 — deletion protection must be enabled
# ---------------------------------------------------------------------------

resource "aws_lb" "deletion_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                       = "regression-alb-deletion-fail"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = false # intentional violation
  enable_http2               = true
  idle_timeout               = 60
  desync_mitigation_mode     = "defensive"

  access_logs {
    bucket  = var.logs_bucket_id
    enabled = true
  }

  tags = merge(var.tags, {
    Name            = "regression-alb-deletion-fail"
    compliance_test = "intentional_violation"
    controls        = "ELB.6"
  })
}

# ---------------------------------------------------------------------------
# ELB.12 — desync_mitigation_mode must be "defensive" or "strictest"
# ---------------------------------------------------------------------------

resource "aws_lb" "desync_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                       = "regression-alb-desync-fail"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  enable_http2               = true
  idle_timeout               = 60
  desync_mitigation_mode     = "monitor" # intentional violation

  access_logs {
    bucket  = var.logs_bucket_id
    enabled = true
  }

  tags = merge(var.tags, {
    Name            = "regression-alb-desync-fail"
    compliance_test = "intentional_violation"
    controls        = "ELB.12"
  })
}

# ---------------------------------------------------------------------------
# ELB.13 — ALB must span multiple Availability Zones
# ---------------------------------------------------------------------------

resource "aws_lb" "multiaz_fail" {
  count = var.create_failing_resources ? 1 : 0

  name                       = "regression-alb-multiaz-fail"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = [var.public_subnet_ids[0]] # intentional violation: single AZ
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  enable_http2               = true
  idle_timeout               = 60
  desync_mitigation_mode     = "defensive"

  access_logs {
    bucket  = var.logs_bucket_id
    enabled = true
  }

  tags = merge(var.tags, {
    Name            = "regression-alb-multiaz-fail"
    compliance_test = "intentional_violation"
    controls        = "ELB.13"
  })
}
