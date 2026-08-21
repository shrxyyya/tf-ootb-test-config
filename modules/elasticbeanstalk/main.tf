# ---------------------------------------------------------------------------
# modules/elasticbeanstalk/main.tf
#
# Security controls covered:
#   ElasticBeanstalk.1 — Enhanced health reporting enabled
#   ElasticBeanstalk.2 — Managed platform updates enabled
#   ElasticBeanstalk.3 — CloudWatch log streaming enabled
# ---------------------------------------------------------------------------

resource "aws_elastic_beanstalk_application" "main" {
  name        = "regression-test"
  description = "Regression test application for Elastic Beanstalk security controls"
  tags        = var.tags
}

# ---------------------------------------------------------------------------
# Pass environment — all three controls satisfied
# ---------------------------------------------------------------------------

resource "aws_elastic_beanstalk_environment" "pass" {
  name                = "regression-test-pass"
  application         = aws_elastic_beanstalk_application.main.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.0.0 running Python 3.11"
  tier                = "WebServer"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.private_subnet_ids)
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.instance_profile_name
  }

  # ElasticBeanstalk.1 — enhanced health reporting
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # ElasticBeanstalk.2 — managed platform updates
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  # ElasticBeanstalk.3 — CloudWatch log streaming
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "30"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Fail: ElasticBeanstalk.1 — basic health reporting (not enhanced)
# ---------------------------------------------------------------------------

resource "aws_elastic_beanstalk_environment" "health_fail" {
  count               = var.create_failing_resources ? 1 : 0
  name                = "regression-test-health-fail"
  application         = aws_elastic_beanstalk_application.main.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.0.0 running Python 3.11"
  tier                = "WebServer"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.private_subnet_ids)
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.instance_profile_name
  }

  # intentional violation: basic instead of enhanced
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "basic"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "30"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "ElasticBeanstalk.1"
  })
}

# ---------------------------------------------------------------------------
# Fail: ElasticBeanstalk.2 — managed platform updates disabled
# ---------------------------------------------------------------------------

resource "aws_elastic_beanstalk_environment" "managed_updates_fail" {
  count               = var.create_failing_resources ? 1 : 0
  name                = "regression-test-updates-fail"
  application         = aws_elastic_beanstalk_application.main.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.0.0 running Python 3.11"
  tier                = "WebServer"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.private_subnet_ids)
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.instance_profile_name
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # intentional violation: managed actions disabled
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "30"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "ElasticBeanstalk.2"
  })
}

# ---------------------------------------------------------------------------
# Fail: ElasticBeanstalk.3 — CloudWatch log streaming disabled
# ---------------------------------------------------------------------------

resource "aws_elastic_beanstalk_environment" "log_streaming_fail" {
  count               = var.create_failing_resources ? 1 : 0
  name                = "regression-test-logs-fail"
  application         = aws_elastic_beanstalk_application.main.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.0.0 running Python 3.11"
  tier                = "WebServer"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.private_subnet_ids)
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.instance_profile_name
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  # intentional violation: log streaming disabled
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "false"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "ElasticBeanstalk.3"
  })
}
