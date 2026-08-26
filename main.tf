# ---------------------------------------------------------------------------
# main.tf — root module wiring all 54 service modules
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Tier 1 — Foundation (no cross-module inputs)
# ---------------------------------------------------------------------------

module "kms" {
  source = "./modules/kms"

  create_failing_resources = var.create_failing_resources
  tags                     = var.tags
}

# module "iam" {
#   source = "./modules/iam"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "s3" {
#   source = "./modules/s3"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# # ---------------------------------------------------------------------------
# # Tier 2 — Core compute/network (depend on kms + iam)
# # ---------------------------------------------------------------------------

# module "ec2" {
#   source = "./modules/ec2"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   public_subnet_ids        = aws_subnet.public[*].id
#   availability_zones       = var.availability_zones
#   instance_profile_name    = module.iam.ec2_instance_profile_name
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "cloudtrail" {
#   source = "./modules/cloudtrail"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
#   cloudwatch_role_arn      = module.iam.cloudtrail_cloudwatch_role_arn
# }

# module "rds" {
#   source = "./modules/rds"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   availability_zones       = var.availability_zones
#   kms_key_arn              = module.kms.shared_key_arn
#   rds_monitoring_role_arn  = module.iam.rds_monitoring_role_arn
# }

# module "eks" {
#   source = "./modules/eks"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   availability_zones       = var.availability_zones
#   kms_key_arn              = module.kms.shared_key_arn
#   eks_cluster_role_arn     = module.iam.eks_cluster_role_arn
#   eks_node_role_arn        = module.iam.eks_node_role_arn
# }

# module "lambda" {
#   source = "./modules/lambda"

#   create_failing_resources  = var.create_failing_resources
#   tags                      = var.tags
#   vpc_id                    = aws_vpc.main.id
#   private_subnet_ids        = aws_subnet.private[*].id
#   kms_key_arn               = module.kms.shared_key_arn
#   lambda_execution_role_arn = module.iam.lambda_execution_role_arn
# }

# # ---------------------------------------------------------------------------
# # Tier 3 — ELB + WAF (depend on s3; WAF needs ELB ARN)
# # ---------------------------------------------------------------------------

# module "elb" {
#   source = "./modules/elb"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   public_subnet_ids        = aws_subnet.public[*].id
#   private_subnet_ids       = aws_subnet.private[*].id
#   logs_bucket_id           = module.s3.logs_bucket_id
# }

# module "waf" {
#   source = "./modules/waf"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   alb_arn                  = module.elb.alb_arn
#   logs_bucket_arn          = module.s3.logs_bucket_arn
# }

# # ---------------------------------------------------------------------------
# # Tier 4 — ECS (depends on kms + iam + ec2)
# # ---------------------------------------------------------------------------

# module "ecs" {
#   source = "./modules/ecs"

#   create_failing_resources    = var.create_failing_resources
#   tags                        = var.tags
#   vpc_id                      = aws_vpc.main.id
#   private_subnet_ids          = aws_subnet.private[*].id
#   kms_key_arn                 = module.kms.shared_key_arn
#   ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
#   app_security_group_id       = module.ec2.app_security_group_id
# }

# # ---------------------------------------------------------------------------
# # Tier 5 — Services depending on elb + waf + s3 + kms + iam
# # ---------------------------------------------------------------------------

# module "cloudfront" {
#   source = "./modules/cloudfront"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   logs_bucket_id           = module.s3.logs_bucket_id
#   wafv2_web_acl_arn        = module.waf.wafv2_web_acl_arn
# }

# module "api_gateway" {
#   source = "./modules/api-gateway"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   wafv2_web_acl_arn        = module.waf.wafv2_web_acl_arn
# }

# module "autoscaling_group" {
#   source = "./modules/autoscaling-group"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   public_subnet_ids        = aws_subnet.public[*].id
#   availability_zones       = var.availability_zones
#   kms_key_arn              = module.kms.shared_key_arn
#   target_group_arn         = module.elb.target_group_arn
#   instance_profile_name    = module.iam.ec2_instance_profile_name
# }

# # ---------------------------------------------------------------------------
# # Data services
# # ---------------------------------------------------------------------------

# module "redshift" {
#   source = "./modules/redshift"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "redshift_serverless" {
#   source = "./modules/redshiftserverless"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "dynamo_db" {
#   source = "./modules/dynamo-db"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "kinesis" {
#   source = "./modules/kinesis"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
#   logs_bucket_id           = module.s3.logs_bucket_id
#   logs_bucket_arn          = module.s3.logs_bucket_arn
# }

# module "opensearch" {
#   source = "./modules/opensearch"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "elasticsearch" {
#   source = "./modules/elasticsearch"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "msk" {
#   source = "./modules/msk"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "neptune" {
#   source = "./modules/neptune"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "docdb" {
#   source = "./modules/docdb"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "elasticache" {
#   source = "./modules/elasticache"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   private_subnet_cidrs     = var.private_subnet_cidrs
#   kms_key_arn              = module.kms.shared_key_arn
# }

# # ---------------------------------------------------------------------------
# # Messaging + secrets
# # ---------------------------------------------------------------------------

# module "secretsmanager" {
#   source = "./modules/secretsmanager"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "sqs" {
#   source = "./modules/sqs"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "sns" {
#   source = "./modules/sns"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
# }

# # ---------------------------------------------------------------------------
# # Developer / analytics services
# # ---------------------------------------------------------------------------

# module "athena" {
#   source = "./modules/athena"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
#   logs_bucket_id           = module.s3.logs_bucket_id
# }

# module "codebuild" {
#   source = "./modules/codebuild"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
#   logs_bucket_id           = module.s3.logs_bucket_id
#   logs_bucket_arn          = module.s3.logs_bucket_arn
# }

# module "datasync" {
#   source = "./modules/datasync"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   logs_bucket_arn          = module.s3.logs_bucket_arn
# }

# module "glue" {
#   source = "./modules/glue"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
#   logs_bucket_id           = module.s3.logs_bucket_id
# }

# module "emr" {
#   source = "./modules/emr"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
#   logs_bucket_id           = module.s3.logs_bucket_id
# }

# module "sagemaker" {
#   source = "./modules/sagemaker"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   kms_key_arn              = module.kms.shared_key_arn
# }

# # ---------------------------------------------------------------------------
# # Storage
# # ---------------------------------------------------------------------------

# module "backup" {
#   source = "./modules/backup"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "efs" {
#   source = "./modules/efs"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "fsx" {
#   source = "./modules/fsx"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "ecr" {
#   source = "./modules/ecr"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# # ---------------------------------------------------------------------------
# # Orchestration + events
# # ---------------------------------------------------------------------------

# module "stepfunction" {
#   source = "./modules/stepfunction"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "eventbridge" {
#   source = "./modules/eventbridge"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# # ---------------------------------------------------------------------------
# # Network + security services
# # ---------------------------------------------------------------------------

# module "network_firewall" {
#   source = "./modules/network-firewall"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "guardduty" {
#   source = "./modules/guardduty"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "inspector" {
#   source = "./modules/inspector"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "macie" {
#   source = "./modules/macie"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# # ---------------------------------------------------------------------------
# # Application + middleware services
# # ---------------------------------------------------------------------------

# module "appsync" {
#   source = "./modules/appsync"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   kms_key_arn              = module.kms.shared_key_arn
# }

# module "mq" {
#   source = "./modules/mq"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
# }

# module "connect" {
#   source = "./modules/connect"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "dms" {
#   source = "./modules/dms"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
# }

# module "transfer" {
#   source = "./modules/transfer"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
# }

# module "elasticbeanstalk" {
#   source = "./modules/elasticbeanstalk"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   instance_profile_name    = module.iam.ec2_instance_profile_name
# }

# # ---------------------------------------------------------------------------
# # Specialist / global services
# # ---------------------------------------------------------------------------

# module "acm" {
#   source = "./modules/acm"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "route53" {
#   source = "./modules/route53"

#   providers = {
#     aws           = aws
#     aws.us_east_1 = aws.us_east_1
#   }

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "ssm" {
#   source = "./modules/ssm"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "servicecatalog" {
#   source = "./modules/servicecatalog"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
# }

# module "workspaces" {
#   source = "./modules/workspaces"

#   create_failing_resources = var.create_failing_resources
#   tags                     = var.tags
#   vpc_id                   = aws_vpc.main.id
#   private_subnet_ids       = aws_subnet.private[*].id
#   kms_key_arn              = module.kms.shared_key_arn
# }
