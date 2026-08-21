# Terraform Security Controls Regression Test Suite — Plan

## Purpose

This repo provides **Terraform HCL infrastructure** that serves as a regression
test fixture for Sentinel and Terraform compliance policies written against:

- [AWS Foundational Security Best Practices (FSBP)](https://docs.aws.amazon.com/securityhub/latest/userguide/fsbp-standard.html)
- [CIS AWS Foundations Benchmark v5.0.0](https://docs.aws.amazon.com/securityhub/latest/userguide/cis-aws-foundations-benchmark.html)

The primary reference for module structure is the
[HashiCorp FSBP policy library](https://github.com/hashicorp/policy-library-fsbp-policy-set-for-aws-terraform).
Every service module in this repo maps 1:1 to a policy directory in that library.
CIS controls that overlap with FSBP are covered by the same resources. CIS-specific
controls with no FSBP equivalent are added to the relevant service module.

---

## Design Decisions

### 1 — All three Sentinel policy evaluation phases are targeted

Policies run at `plan`, `apply`, and `state` phases. All resources must be fully
applied to a real AWS account — no `count = 0` guards, no plan-only stubs.
State-phase controls (e.g. whether GuardDuty is currently enabled, whether a
CloudTrail trail is actively delivering logs) require real applied state.

The test workflow: `terraform apply` → run policy checks → `terraform destroy`.
All infra is destroyed after each test run. The test account is a dedicated
sandbox with no other workloads.

### 2 — HCP Terraform with remote execution

State backend is HCP Terraform (`cloud` block) with remote execution mode.
Sentinel runs natively in HCP Terraform workspaces alongside the state. No
separate S3/DynamoDB bootstrap required. Terraform ≥ 1.9, AWS provider ~> 5.0.

### 3 — Single workspace, pass and fail resources coexist

One HCP Terraform workspace. Pass and fail resources live in the same state.
Policies discriminate by resource address (`module.s3.aws_s3_bucket.pass` vs
`module.s3.aws_s3_bucket.fail`) and by the `compliance_test` tag.

Two-workspace splits were rejected — they double apply/destroy cost and add
orchestration complexity with no policy-testing benefit.

### 4 — Tag-based exemption, not soft-mandatory override

Fail resources carry `compliance_test = "intentional_violation"` in their tags.
Sentinel policies filter out resources with this tag before enforcing, so the
apply proceeds automatically without human override clicks.

Soft-mandatory override requires a human action on every apply run, which breaks
CI automation. Tag-based exemption is fully automated and auditable, and matches
the real-world exemption pattern used in production policy sets.

### 5 — Singleton resources are toggle-driven, default = fail

Account-level singletons (`aws_iam_account_password_policy`,
`aws_ebs_encryption_by_default`, AWS Config recorder, GuardDuty detector) cannot
have simultaneous pass and fail instances. They are controlled by the
`create_failing_resources` variable:

- `true` (default) — non-compliant configuration, policies fire
- `false` — compliant configuration, verifies no false positives

Default is `true` because the primary purpose is regression testing detection,
not absence of false positives.

### 6 — Module structure mirrors the HashiCorp FSBP library exactly

54 service modules under `modules/`, named identically to the policy directories
in `hashicorp/policy-library-fsbp-policy-set-for-aws-terraform`. This makes
it unambiguous which Terraform module exercises which policy file.

Controls not exercisable via Terraform plan/apply (account-level read-only state
checks, root account MFA, hardware MFA) are documented in the relevant module
with an explanation.

### 7 — Production-realistic attributes everywhere except the intentional violation

Every attribute that is not the subject of the control being tested is set to a
production-realistic value. The intentional violation is **surgical** — exactly
one attribute differs between a pass resource and its paired fail resource.
Everything else is identical and realistic: real engine versions, real instance
classes, real VPC configurations, real IAM policy structures.

Minimal or default-only values are not acceptable. This suite is the golden
standard regression baseline; it must test policies against the kind of
infrastructure they will encounter in production.

### 8 — Mixed workload archetype

Resources are grounded in a mixed production environment:

- **Web app tier**: ALB + ECS/EKS + ElastiCache + CloudFront + WAF + ACM
- **Data platform tier**: S3 + Redshift + DynamoDB + Kinesis + Glue + EMR + MSK
- **Container platform tier**: ECR + ECS + EKS + Lambda + API Gateway

This gives every service module a realistic hosting context without forcing
artificial resource inclusions.

---

## Pass/Fail Mechanics

Resources are named `.pass` and `.fail` within each module:

```hcl
# modules/s3/main.tf

# Pass: all attributes production-realistic, block public access enabled
resource "aws_s3_bucket_public_access_block" "pass" {
  bucket                  = aws_s3_bucket.pass.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Fail: intentional violation — all four block flags false
# All other bucket attributes (lifecycle, logging, versioning) identical to pass
resource "aws_s3_bucket_public_access_block" "fail" {
  bucket                  = aws_s3_bucket.fail.id
  block_public_acls       = false   # intentional_violation: S3.1 / CIS-2.1.4
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  tags = {
    compliance_test = "intentional_violation"
    controls        = "S3.1,CIS-2.1.4"
  }
}
```

Sentinel policy assertion pattern:

```python
import "tfplan/v2" as tfplan

# Skip resources tagged as intentional test violations
is_exempt = func(r) {
  tags = r.change.after.tags else {}
  return (tags["compliance_test"] else "") is "intentional_violation"
}

# S3.1 — all S3 buckets must have block public access enabled
deny_s3_public = rule {
  all tfplan.resource_changes as _, r {
    r.type is not "aws_s3_bucket_public_access_block" or
    is_exempt(r) or
    (r.change.after.block_public_acls is true and
     r.change.after.restrict_public_buckets is true)
  }
}
```

The `fail` resource triggers the deny. The `pass` resource does not.
The `fail` resource's `compliance_test` tag prevents the apply from being blocked.

---

## Root Variables

```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "create_failing_resources" {
  description = "When true (default), singleton resources deploy in non-compliant config. Set false to verify no false positives."
  default     = true
}

variable "hcp_org" {
  description = "HCP Terraform organization name"
}

variable "hcp_workspace" {
  description = "HCP Terraform workspace name"
  default     = "security-controls-regression"
}

variable "tags" {
  default = {
    Project     = "security-policy-regression"
    ManagedBy   = "terraform"
    AutoShutdown = "true"
  }
}
```

---

## Folder Structure

```
tf-ootb-test-config/
├── PLAN.md
├── CONTEXT.md
├── README.md
├── main.tf                   ← root: wires all 54 service modules
├── variables.tf
├── outputs.tf
├── versions.tf               ← terraform >= 1.9, aws ~> 5.0
├── provider.tf               ← AWS provider
├── backend.tf                ← HCP Terraform cloud block
│
└── modules/
    ├── acm/
    ├── api-gateway/
    ├── appsync/
    ├── athena/
    ├── autoscaling-group/
    ├── backup/
    ├── cloudfront/
    ├── cloudtrail/
    ├── codebuild/
    ├── connect/
    ├── datasync/
    ├── dms/
    ├── docdb/
    ├── dynamo-db/
    ├── ec2/
    ├── ecr/
    ├── ecs/
    ├── efs/
    ├── eks/
    ├── elasticache/
    ├── elasticbeanstalk/
    ├── elasticsearch/
    ├── elb/
    ├── emr/
    ├── eventbridge/
    ├── fsx/
    ├── glue/
    ├── guardduty/
    ├── iam/
    ├── inspector/
    ├── kinesis/
    ├── kms/
    ├── lambda/
    ├── macie/
    ├── mq/
    ├── msk/
    ├── neptune/
    ├── network-firewall/
    ├── opensearch/
    ├── rds/
    ├── redshift/
    ├── redshiftserverless/
    ├── route53/
    ├── s3/
    ├── sagemaker/
    ├── secretsmanager/
    ├── servicecatalog/
    ├── sns/
    ├── sqs/
    ├── ssm/
    ├── stepfunction/
    ├── transfer/
    ├── waf/
    └── workspaces/
```

Each module:
```
modules/<service>/
├── main.tf        ← pass + fail resources, production-realistic attributes
├── variables.tf   ← create_failing_resources, tags, vpc/subnet refs
└── outputs.tf     ← resource IDs/ARNs for root outputs
```

---

## Controls Coverage by Module

Exact policy filenames from `hashicorp/policy-library-fsbp-policy-set-for-aws-terraform`.
Each row maps one policy file to the Terraform resource(s) it requires.

### acm
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| acm-pca-root-ca-disabled | `aws_acmpca_certificate_authority` | status=DISABLED | status=ACTIVE |
| acm-rsa-certificate-key-length-atleast-2048 | `aws_acm_certificate` | key_algorithm=RSA_2048 | key_algorithm=RSA_1024 |

### api-gateway
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| api-gateway-rest-and-websocket-api-logging-enabled | `aws_api_gateway_stage` | logging_level=INFO | logging_level=OFF |
| api-gateway-access-logging-should-be-configured | `aws_apigatewayv2_stage` | access_log_settings set | omitted |
| api-gateway-rest-cache-have-encryption-enabled | `aws_api_gateway_stage` | cache_cluster_enabled+encrypted | unencrypted |
| api-gateway-rest-configure-ssl-certificates | `aws_api_gateway_stage` | client_certificate_id set | omitted |
| api-gateway-rest-have-x-ray-tracing-enabled | `aws_api_gateway_stage` | xray_tracing_enabled=true | =false |
| api-gateway-routes-should-specify-an-authorization-type | `aws_apigatewayv2_route` | authorization_type=JWT | =NONE |
| api-gateway-should-be-associated-with-a-waf-web-acl | `aws_api_gateway_stage` | web_acl_arn set | omitted |

### appsync
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| appsync-graphqlapi-cache-should-be-encrypted-at-rest | `aws_appsync_api_cache` | at_rest_encryption_enabled=true | =false |
| appsync-cache-should-be-encrypted-at-transit | `aws_appsync_api_cache` | transit_encryption_enabled=true | =false |
| appsync-field-level-logging-should-be-enabled | `aws_appsync_graphql_api` | field_log_level=ERROR | =NONE |
| appsync-graphql-api-should-not-authenticate-with-api-keys | `aws_appsync_graphql_api` | authentication_type=AMAZON_COGNITO_USER_POOLS | =API_KEY |

### athena
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| athena-workgroup-should-have-logging-enabled | `aws_athena_workgroup` | publish_cloudwatch_metrics_enabled=true | =false |

### autoscaling-group
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| autoscaling-group-should-cover-multiple-azs | `aws_autoscaling_group` | availability_zones ≥ 2 | 1 AZ only |
| autoscaling-group-should-use-launch-templates | `aws_autoscaling_group` | launch_template set | launch_configuration set |
| autoscaling-group-should-use-multiple-instance-types | `aws_autoscaling_group` | mixed_instances_policy set | single instance type |
| autoscaling-group-with-load-balancer-attached-should-have-elb-healthcheck | `aws_autoscaling_group` | health_check_type=ELB | =EC2 |
| autoscaling-launch-config-public-ip-disabled | `aws_launch_configuration` | associate_public_ip_address=false | =true |

### backup
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| backup-recovery-point-encrypted | `aws_backup_vault` | kms_key_arn set | omitted (default key) |

### cloudfront
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| cloudfront-should-have-default-root-object-configured | `aws_cloudfront_distribution` | default_root_object="index.html" | ="" |
| cloudfront-should-require-encryption-in-transit | `aws_cloudfront_distribution` | viewer_protocol_policy=redirect-to-https | =allow-all |
| cloudfront-distributions-should-have-origin-failover-configured | `aws_cloudfront_distribution` | origin_group set | omitted |
| cloudfront-distributions-should-have-logging-enabled | `aws_cloudfront_distribution` | logging_config set | omitted |
| cloudfront-associated-with-waf | `aws_cloudfront_distribution` | web_acl_id set | omitted |
| cloudfront-distributions-should-use-custom-ssl-tls-certificates | `aws_cloudfront_distribution` | acm_certificate_arn set | cloudfront default cert |
| cloudfront-distributions-should-use-sni-to-serve-https-requests | `aws_cloudfront_distribution` | ssl_support_method=sni-only | =vip |
| cloudfront-distributions-should-encrypt-traffic-to-custom-origins | `aws_cloudfront_distribution` | origin_ssl_protocols=TLSv1.2 | HTTP only origin |
| cloudfront-distributions-should-not-use-deprecated-ssl-protocols | `aws_cloudfront_distribution` | minimum_protocol_version=TLSv1.2_2021 | =TLSv1 |
| cloudfront-s3-origin-access-control-enabled | `aws_cloudfront_distribution` | origin_access_control_id set | omitted |
| cloudfront-s3-origin-non-existent-bucket | `aws_cloudfront_distribution` | origin points to existing bucket | — (policy-only check) |

### cloudtrail
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| cloudtrail-server-side-encryption-enabled | `aws_cloudtrail` | kms_key_id set | omitted |
| cloudtrail-log-file-validation-enabled | `aws_cloudtrail` | enable_log_file_validation=true | =false |
| cloudtrail-cloudwatch-logs-group-arn-present | `aws_cloudtrail` | cloud_watch_logs_group_arn set | omitted |

CIS additions: `is_multi_region_trail=true` (CIS-3.1), S3 access logging on trail bucket (CIS-3.4).

### codebuild
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| codebuild-project-environments-should-have-a-logging-aws-configuration | `aws_codebuild_project` | logs_config.cloudwatch_logs set | omitted |
| codebuild-s3-logs-should-be-encrypted | `aws_codebuild_project` | logs_config.s3_logs.encryption_disabled=false | =true |
| codebuild-bitbucket-url-should-not-contain-sensitive-credentials | `aws_codebuild_project` | source URL without creds | URL with embedded password |

### connect
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| connect-instance-flow-logging-should-be-enabled | `aws_connect_instance` | inbound_calls_enabled + contact_flow_logs_enabled | logs disabled |

### datasync
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| datasync-task-should-have-logging-enabled | `aws_datasync_task` | cloudwatch_log_group_arn set | omitted |

### dms
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| dms-replication-instances-should-not-be-public | `aws_dms_replication_instance` | publicly_accessible=false | =true |
| dms-auto-minor-version-upgrade-check | `aws_dms_replication_instance` | auto_minor_version_upgrade=true | =false |
| dms-endpoint-should-be-ssl-configured / dms-endpoints-should-use-ssl | `aws_dms_endpoint` | ssl_mode=require | =none |
| dms-replication-task-logging-enabled | `aws_dms_replication_task` | logging enabled in task_settings | disabled |
| dms-mongo-db-authentication-enabled | `aws_dms_endpoint` (mongodb) | auth_type=password | =no |
| dms-redis-tls-enabled | `aws_dms_endpoint` (redis) | ssl_mode=require | =none |

### docdb
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| docdb-cluster-storage-encrypted | `aws_docdb_cluster` | storage_encrypted=true | =false |
| docdb-cluster-backup-retention-check | `aws_docdb_cluster` | backup_retention_period=7 | =1 |
| docdb-cluster-deletion-protection-enabled | `aws_docdb_cluster` | deletion_protection=true | =false |
| docdb-cluster-audit-logging-enabled | `aws_docdb_cluster_parameter_group` | audit_logs=enabled | =disabled |

### dynamo-db
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| dynamo-db-tables-point-in-time-recovery-enabled | `aws_dynamodb_table` | point_in_time_recovery.enabled=true | =false |
| dynamo-db-tables-scales-capacity-with-demand | `aws_dynamodb_table` | billing_mode=PAY_PER_REQUEST | =PROVISIONED without autoscaling |
| dynamo-db-accelerator-clusters-encryption-at-rest-enabled | `aws_dax_cluster` | server_side_encryption.enabled=true | =false |
| dynamo-db-accelerator-clusters-encryption-in-transit-enabled | `aws_dax_cluster` | cluster_endpoint_encryption_type=TLS | =NONE |
| dynamo-db-tables-delete-protection-enabled | `aws_dynamodb_table` | deletion_protection_enabled=true | =false |

### ec2
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| ec2-ebs-encryption-enabled | `aws_ebs_encryption_by_default` | enabled=true (toggle) | enabled=false (toggle) |
| ec2-attached-ebs-volumes-encrypted-at-rest | `aws_ebs_volume` | encrypted=true | =false |
| ec2-metadata-imdsv2-required | `aws_instance` | http_tokens=required | =optional |
| ec2-instance-should-not-have-public-ip | `aws_instance` | associate_public_ip_address=false | =true |
| ec2-instance-should-not-use-multiple-enis | `aws_instance` | single network_interface | multiple aws_network_interface attached |
| ec2-instance-virtualization-should-not-be-paravirtual | `aws_instance` | virtualization_type=hvm (default) | ami with pv virtualization |
| ec2-launch-template-imdsv2-check | `aws_launch_template` | metadata_options.http_tokens=required | =optional |
| ec2-launch-template-public-ip-disabled | `aws_launch_template` | network_interfaces.associate_public_ip_address=false | =true |
| ec2-network-acl | `aws_network_acl_rule` | deny ingress 0.0.0.0/0 on 22/3389 | no deny rule |
| ec2-network-acl-should-have-subnet-ids | `aws_network_acl` | subnet_ids set | omitted |
| ec2-security-group-ingress-traffic-restriction-to-common-ports | `aws_security_group` | no 0.0.0.0/0 on 22/3389 | 0.0.0.0/0 on port 22 |
| ec2-security-group-ingress-traffic-restriction-to-unauthorized-ports | `aws_security_group` | ingress restricted | unrestricted high-risk port |
| ec2-subnet-with-auto-assign-public-ip-disabled | `aws_subnet` | map_public_ip_on_launch=false | =true |
| ec2-transit-gateway-auto-vpc-attach-disabled | `aws_ec2_transit_gateway` | default_route_table_association=disable | =enable |
| ec2-vpc-default-security-group-no-traffic | `aws_default_security_group` | no ingress/egress rules | has ingress rule |
| ec2-vpc-flow-logging-enabled | `aws_flow_log` | traffic_type=ALL on VPC | absent |
| ec2-vpc-block-public-access-options-should-block-internet-gateway-traffic | `aws_vpc_block_public_access_options` | internet_gateway_block_mode=block-bidirectional | =off |
| ec2-service-vpc-endpoint-enabled | `aws_vpc_endpoint` | ec2 endpoint present | absent |
| ec2-vpc-should-be-configured-for-interface-endpoint | `aws_vpc_endpoint` | interface endpoints for SSM/ECR/etc | absent |
| ec2-client-vpn-connection-log-enabled | `aws_ec2_client_vpn_endpoint` | connection_log_options.enabled=true | =false |
| ec2-vpn-connection-logging-enabled | `aws_vpn_connection` | tunnel logging enabled | disabled |
| ec2-ebs-snapshot-public-restorable-check-account-level | — | account-level check, not Terraform-manageable | documented |

### ecr
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| ecr-image-scanning-enabled | `aws_ecr_repository` | image_scanning_configuration.scan_on_push=true | =false |
| ecr-tag-immutability-configured | `aws_ecr_repository` | image_tag_mutability=IMMUTABLE | =MUTABLE |
| ecr-lifecycle-policy-configured | `aws_ecr_lifecycle_policy` | policy set | absent |

### ecs
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| ecs-service-no-public-ip-assignment | `aws_ecs_service` | assign_public_ip=DISABLED | =ENABLED |
| ecs-non-privileged-container-definitions | `aws_ecs_task_definition` | privileged=false | =true |
| ecs-task-definition-read-only-root-file-system-access | `aws_ecs_task_definition` | readonlyRootFilesystem=true | =false |
| ecs-task-definition-no-secrets-as-environment-variables | `aws_ecs_task_definition` | secrets via secrets manager | plaintext env var |
| ecs-task-definition-log-configuration-present | `aws_ecs_task_definition` | logConfiguration set | omitted |
| ecs-task-definition-restrict-process-id | `aws_ecs_task_definition` | pidMode omitted/task | =host |
| ecs-task-definition-secure-networking-mode-and-user-definitions | `aws_ecs_task_definition` | networkMode=awsvpc, non-root user | root user |
| ecs-cluster-enable-container-insights | `aws_ecs_cluster` | setting containerInsights=enabled | =disabled |
| ecs-fargate-service-platform-compatibility | `aws_ecs_task_definition` | requiresCompatibilities=FARGATE, latest platform | old platform |
| ecs-task-set-assign-public-ip-disabled | `aws_ecs_task_set` | network_configuration.assign_public_ip=DISABLED | =ENABLED |

### efs
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| efs-filesystem-encrypted | `aws_efs_file_system` | encrypted=true | =false |
| efs-file-systems-should-be-encrypted-at-rest | `aws_efs_file_system` | kms_key_id set | default key |
| efs-automatic-backups-enabled | `aws_efs_file_system` | `aws_efs_backup_policy` ENABLED | DISABLED |
| efs-file-systems-should-be-in-backup-plans | `aws_backup_plan` | EFS included | absent |
| efs-access-point-should-enforce-root-directory | `aws_efs_access_point` | root_directory.path set | path="/" |
| efs-access-point-should-enforce-user-identity | `aws_efs_access_point` | posix_user set | omitted |

### eks
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| eks-cluster-endpoints-restrict-public-access | `aws_eks_cluster` | endpoint_public_access=false | =true |
| eks-cluster-encrypted-kubernetes-secrets | `aws_eks_cluster` | encryption_config with KMS | absent |
| eks-cluster-audit-logging-enabled | `aws_eks_cluster` | enabled_cluster_log_types includes audit | omitted |
| eks-cluster-supported-k8s-version-check | `aws_eks_cluster` | version=1.30 | =1.24 (EOL) |

### elasticache
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| elasticache-redis-cluster-auto-backup-enabled | `aws_elasticache_cluster` | snapshot_retention_limit≥1 | =0 |
| elasticache-redis-cluster-auto-minor-version-upgrade-enabled | `aws_elasticache_cluster` | auto_minor_version_upgrade=true | =false |
| elasticache-redis-replication-group-auto-failover-enabled | `aws_elasticache_replication_group` | automatic_failover_enabled=true | =false |
| elasticache-redis-replication-group-encryption-at-rest-enabled | `aws_elasticache_replication_group` | at_rest_encryption_enabled=true | =false |
| elasticache-redis-replication-group-encryption-at-transit-enabled | `aws_elasticache_replication_group` | transit_encryption_enabled=true | =false |
| elasticache-redis-replication-group-redis-auth-enabled | `aws_elasticache_replication_group` | auth_token set | omitted |
| elasticache-redis-cluster-non-default-subnet-enabled | `aws_elasticache_subnet_group` | custom subnet group | default |

### elasticbeanstalk
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| elasticbeanstalk-enhanced-health-reporting-enabled | `aws_elastic_beanstalk_environment` | health_reporting=enhanced | =basic |
| elasticbeanstalk-managed-platform-updates-enabled | `aws_elastic_beanstalk_environment` | managed_updates enabled | disabled |
| elasticbeanstalk-cloudwatch-log-streaming-enabled | `aws_elastic_beanstalk_environment` | stream_logs=true | =false |

### elasticsearch
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| elasticsearch-encrypted-at-rest | `aws_elasticsearch_domain` | encrypt_at_rest.enabled=true | =false |
| elasticsearch-in-vpc-only | `aws_elasticsearch_domain` | vpc_options set | omitted |
| elasticsearch-node-to-node-encryption-check | `aws_elasticsearch_domain` | node_to_node_encryption.enabled=true | =false |
| elasticsearch-logs-to-cloudwatch | `aws_elasticsearch_domain` | log_publishing_options set | omitted |
| elasticsearch-audit-logging-enabled | `aws_elasticsearch_domain` | AUDIT_LOGS log type enabled | omitted |
| elasticsearch-domains-should-have-atleast-three-data-nodes | `aws_elasticsearch_domain` | instance_count≥3 | =1 |
| elasticsearch-primary-node-fault-tolerance | `aws_elasticsearch_domain` | dedicated_master_enabled=true, count≥3 | =false |
| elasticsearch-https-required | `aws_elasticsearch_domain` | domain_endpoint_options.enforce_https=true | =false |

### elb
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| elb-drop-invalid-http-headers | `aws_lb` | drop_invalid_header_fields=true | =false |
| elb-ensure-access-logging-enabled | `aws_lb` | access_logs.enabled=true | =false |
| elb-ensure-deletion-protection-enabled | `aws_lb` | enable_deletion_protection=true | =false |
| elb-ensure-http-request-redirection | `aws_lb_listener` | redirect to HTTPS on port 80 | forward on port 80 |
| elb-ensure-ssl-listener-acm-cert-classic-load-balancer | `aws_lb_listener` | certificate_arn set (ACM) | no cert |
| elb-ensure-ssl-listener-predefined-security-policy | `aws_lb_listener` | ssl_policy=ELBSecurityPolicy-TLS13-1-2-2021-06 | weak policy |
| elb-connection-draining-enabled | `aws_elb` (classic) | connection_draining=true | =false |
| elb-cross-zone-load-balancing-enabled | `aws_elb` (classic) | cross_zone_load_balancing=true | =false |
| elb-ensure-multi-az-configuration-classic-load-balancer | `aws_elb` | subnets across ≥2 AZs | single AZ |
| elb-multiple-az | `aws_lb` | subnets across ≥2 AZs | single AZ |
| elb-configure-https-tls-termination-classic-load-balancer | `aws_elb` | HTTPS listener | HTTP only |
| elb-ensure-valid-desync-mitigation-mode | `aws_lb` | desync_mitigation_mode=defensive | =monitor |
| elb-predefined-security-policy-ssl-check | `aws_lb_listener` | ssl_policy=TLS13 policy | weak policy |

### emr
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| emr-block-public-access-enabled | `aws_emr_block_public_access_configuration` | block_public_security_group_rules=true (toggle) | =false |
| emr-security-configuration-encryption-rest | `aws_emr_security_configuration` | at_rest encryption enabled | disabled |
| emr-security-configuration-encryption-transit | `aws_emr_security_configuration` | in_transit encryption enabled | disabled |

### eventbridge
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| eventbridge-custom-event-bus-should-have-attached-policy | `aws_cloudwatch_event_bus_policy` | resource policy set | absent |

### fsx
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| fsx-openzfs-copy-tags-to-backups-and-volumes-enabled | `aws_fsx_openzfs_file_system` | copy_tags_to_backups=true, copy_tags_to_volumes=true | =false |
| fsx-lustre-copy-tags-to-backups | `aws_fsx_lustre_file_system` | copy_tags_to_backups=true | =false |
| fsx-openzfs-deployment-type-check | `aws_fsx_openzfs_file_system` | deployment_type=MULTI_AZ_1 | =SINGLE_AZ_1 |
| fsx-ontap-deployment-type-check | `aws_fsx_ontap_file_system` | deployment_type=MULTI_AZ_1 | =SINGLE_AZ_1 |
| fsx-windows-deployment-type-check | `aws_fsx_windows_file_system` | deployment_type=MULTI_AZ_1 | =SINGLE_AZ_1 |

### glue
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| glue-spark-job-supported-version | `aws_glue_job` | glue_version=4.0 | =2.0 (EOL) |

### guardduty
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| guardduty-should-be-enabled | `aws_guardduty_detector` | enable=true (toggle) | enable=false (toggle) |
| guardduty-s3-protection-should-be-enabled | `aws_guardduty_detector` | datasources.s3_logs.enable=true | =false |
| guardduty-eks-audit-log-monitoring-should-be-enabled | `aws_guardduty_detector` | datasources.kubernetes.audit_logs.enable=true | =false |
| guardduty-malware-protection-enabled | `aws_guardduty_detector` | datasources.malware_protection enabled | disabled |
| guardduty-eks-protection-runtime-should-be-enabled | `aws_guardduty_detector` | features EKS_RUNTIME_MONITORING enabled | disabled |
| guardduty-ecs-protection-runtime-enabled | `aws_guardduty_detector` | features ECS_RUNTIME_MONITORING enabled | disabled |
| guardduty-runtime-monitoring-enabled | `aws_guardduty_detector` | features RUNTIME_MONITORING enabled | disabled |

### iam
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| iam-no-admin-privileges-allowed-by-policies | `aws_iam_policy` | scoped actions | Action=* Resource=* |
| iam-no-policies-attached-to-users | `aws_iam_user` / `aws_iam_user_policy_attachment` | policy via group only | direct attachment |
| iam-password-policy-strong-configuration | `aws_iam_account_password_policy` | min_length=14, reuse=24 (toggle) | min_length=6 (toggle) |
| iam-policy-no-statements-with-full-access | `aws_iam_policy` | no service:* wildcards | service:* in statement |

CIS additions: support role (CIS-1.16), Access Analyzer (CIS-1.19 via `aws_accessanalyzer_analyzer`), MFA device presence (CIS-1.9).

### inspector
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| inspector-ec2-scan-enabled | `aws_inspector2_enabler` | resource_types includes EC2 | absent |
| inspector-ecr-scan-enabled | `aws_inspector2_enabler` | resource_types includes ECR | absent |
| inspector-lambda-code-scan-enabled | `aws_inspector2_enabler` | resource_types includes LAMBDA_CODE | absent |
| inspector-lambda-standard-scan-enabled | `aws_inspector2_enabler` | resource_types includes LAMBDA | absent |

### kinesis
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| kinesis-stream-encrypted | `aws_kinesis_stream` | encryption_type=KMS | =NONE |
| kinesis-firehose-delivery-stream-encrypted | `aws_kinesis_firehose_delivery_stream` | server_side_encryption.enabled=true | =false |
| kinesis-stream-backup-retention-check | `aws_kinesis_stream` | retention_period≥168 | =24 |

### kms
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| kms-restrict-iam-inline-policies-decrypt-all-kms-keys | `aws_iam_role_policy` | scoped kms:Decrypt to specific key ARN | kms:Decrypt on Resource=* |

CIS additions: key rotation (CIS-3.6 via `enable_key_rotation=true`/`false`).

### lambda
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| lambda-function-public-access-prohibited | `aws_lambda_permission` | principal=account only | principal=* |
| lambda-functions-should-use-supported-runtimes | `aws_lambda_function` | runtime=python3.12 | =python3.7 (EOL) |
| lambda-vpc-multi-az-check | `aws_lambda_function` | vpc_config with subnets in ≥2 AZs | no vpc_config |

### macie
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| macie-status-should-be-enabled | `aws_macie2_account` | status=ENABLED | status=PAUSED |

### mq
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| mq-cloudwatch-audit-log-enabled | `aws_mq_broker` | logs.audit=true | =false |
| mq-auto-minor-version-upgrade-enabled | `aws_mq_broker` | auto_minor_version_upgrade=true | =false |

### msk
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| msk-in-cluster-node-require-encrypted-in-transit | `aws_msk_cluster` | encryption_in_transit.client_broker=TLS | =PLAINTEXT |
| msk-connect-connector-encrypted | `aws_mskconnect_connector` | encryption in transit | plaintext |

### neptune
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| neptune-cluster-encryption-at-rest-enabled | `aws_neptune_cluster` | storage_encrypted=true | =false |
| neptune-cluster-audit-logs-publishing-enabled | `aws_neptune_cluster` | enable_cloudwatch_logs_exports includes audit | omitted |
| neptune-cluster-deletion-protection-enabled | `aws_neptune_cluster` | deletion_protection=true | =false |
| neptune-cluster-automated-backups-enabled | `aws_neptune_cluster` | backup_retention_period≥7 | =1 |
| neptune-cluster-snapshot-encryption-at-rest-enabled | `aws_neptune_cluster_snapshot` | storage_encrypted=true | =false |
| neptune-cluster-db-auth-enabled | `aws_neptune_cluster` | iam_database_authentication_enabled=true | =false |
| neptune-cluster-copy-tags-to-snapshot-enabled | `aws_neptune_cluster` | copy_tags_to_snapshot=true | =false |

### network-firewall
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| network-firewall-logging-enabled | `aws_networkfirewall_logging_configuration` | log destinations set | absent |
| network-firewall-policy-rule-group-associated | `aws_networkfirewall_policy` | stateless_rule_group_reference set | empty |
| network-firewall-policy-default-action-full-packets | `aws_networkfirewall_policy` | stateless_default_actions=aws:drop | =aws:pass |
| network-firewall-policy-default-action-fragmented-packets | `aws_networkfirewall_policy` | stateless_fragment_default_actions=aws:drop | =aws:pass |
| network-firewall-stateless-rule-group | `aws_networkfirewall_rule_group` | rules_source has rules | empty |
| network-firewall-should-have-deletion-protection-enabled | `aws_networkfirewall_firewall` | delete_protection=true | =false |
| network-firewall-subnet-change-protection-enabled | `aws_networkfirewall_firewall` | subnet_change_protection=true | =false |

### opensearch
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| opensearch-encrypted-at-rest | `aws_opensearch_domain` | encrypt_at_rest.enabled=true | =false |
| opensearch-in-vpc-only | `aws_opensearch_domain` | vpc_options set | omitted |
| opensearch-node-to-node-encryption-check | `aws_opensearch_domain` | node_to_node_encryption.enabled=true | =false |
| opensearch-logs-to-cloudwatch | `aws_opensearch_domain` | log_publishing_options set | omitted |
| opensearch-audit-logging-enabled | `aws_opensearch_domain` | AUDIT_LOGS enabled | omitted |
| opensearch-data-node-fault-tolerance | `aws_opensearch_domain` | instance_count≥3 | =1 |
| opensearch-access-control-enabled | `aws_opensearch_domain` | advanced_security_options.enabled=true | =false |
| opensearch-https-required | `aws_opensearch_domain` | enforce_https=true | =false |
| opensearch-update-check | `aws_opensearch_domain` | engine_version=latest | outdated version |

### rds
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| rds-encryption-at-rest-enabled | `aws_db_instance` | storage_encrypted=true | =false |
| rds-instance-should-be-private | `aws_db_instance` | publicly_accessible=false | =true |
| rds-ensure-multi-az-configuration | `aws_db_instance` | multi_az=true | =false |
| rds-ensure-deletion-protection-enabled | `aws_db_instance` | deletion_protection=true | =false |
| rds-ensure-automatic-backups-enabled | `aws_db_instance` | backup_retention_period=7 | =0 |
| rds-ensure-automatic-minor-version-upgrades-enabled | `aws_db_instance` | auto_minor_version_upgrade=true | =false |
| rds-ensure-monitoring-configured | `aws_db_instance` | monitoring_interval=60 | =0 |
| rds-ensure-cluster-and-db-instance-iam-auth-configured | `aws_db_instance` | iam_database_authentication_enabled=true | =false |
| rds-ensure-cloudwatch-logs-enabled | `aws_db_instance` | enabled_cloudwatch_logs_exports set | omitted |
| rds-cluster-encrypted-at-rest | `aws_rds_cluster` | storage_encrypted=true | =false |
| rds-ensure-cluster-multi-az-configured | `aws_rds_cluster` | availability_zones ≥ 3 | single AZ |
| rds-ensure-cluster-backtracking-enabled | `aws_rds_cluster` | backtrack_window>0 | =0 |
| rds-cluster-default-admin-check | `aws_rds_cluster` | master_username != admin/postgres | =admin |
| rds-instance-default-admin-check | `aws_db_instance` | username != admin | =admin |
| rds-ensure-no-default-port | `aws_db_instance` | port != 3306/5432 (default) | =3306 |
| rds-copy-tags-to-snapshot-configured | `aws_db_instance` | copy_tags_to_snapshot=true | =false |
| rds-cluster-and-db-snapshot-encrypted | `aws_db_snapshot` | encrypted=true | =false |
| rds-instance-deployed-in-vpc | `aws_db_instance` | db_subnet_group_name set | omitted |
| rds-event-notifications-configured-for-critical-events | `aws_db_event_subscription` | source_type=db-instance, categories set | omitted |
| rds-aurora-mysql-audit-logging-enabled | `aws_rds_cluster` (aurora-mysql) | enabled_cloudwatch_logs_exports includes audit | omitted |
| aurora-postgresql-db-clusters-should-publish-logs-to-cloudwatch-logs | `aws_rds_cluster` (aurora-postgresql) | logs enabled | omitted |
| rds-for-postgresql-db-instances-should-publish-logs-to-cloudwatch-logs | `aws_db_instance` (postgres) | logs enabled | omitted |
| rds-for-sql-server-db-instances-should-be-encrypted-in-transit | `aws_db_option_group` (sqlserver) | SSL option enforced | omitted |
| rds-for-sql-server-db-instances-should-publish-logs-to-cloudwatch-logs | `aws_db_instance` (sqlserver) | logs enabled | omitted |
| rds-for-mariadb-db-instances-should-publish-logs-to-cloudwatch-logs | `aws_db_instance` (mariadb) | logs enabled | omitted |
| rds-for-mariadb-db-instances-should-be-encrypted-in-transit | `aws_db_parameter_group` (mariadb) | require_secure_transport=ON | =OFF |

### redshift
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| redshift-cluster-public-access-check | `aws_redshift_cluster` | publicly_accessible=false | =true |
| redshift-cluster-should-be-encrypted-at-rest | `aws_redshift_cluster` | encrypted=true | =false |
| redshift-cluster-should-be-encrypted-at-transit | `aws_redshift_parameter_group` | require_ssl=true | =false |
| redshift-cluster-automated-snapshot-retention-enabled | `aws_redshift_cluster` | automated_snapshot_retention_period≥7 | =1 |
| redshift-cluster-audit-logging-enabled | `aws_redshift_cluster` | logging.enable=true | =false |
| redshift-cluster-enhanced-vpc-routing-enabled | `aws_redshift_cluster` | enhanced_vpc_routing=true | =false |
| redshift-cluster-maintenance-settings-check | `aws_redshift_cluster` | allow_version_upgrade=true | =false |
| redshift-cluster-default-admin-check | `aws_redshift_cluster` | master_username!=awsuser | =awsuser |
| redshift-cluster-default-db-name-check | `aws_redshift_cluster` | database_name!=dev | =dev |
| redshift-cluster-unrestricted-port-access-check | `aws_security_group` | redshift port not open to 0.0.0.0/0 | open to 0.0.0.0/0 |

### redshiftserverless
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| redshift-serverless-workgroups-should-use-enhanced-vpc-routing | `aws_redshiftserverless_workgroup` | enhanced_vpc_routing=true | =false |
| redshift-serverless-workgroups-should-be-required-to-use-ssl | `aws_redshiftserverless_namespace` | require_ssl config parameter=true | =false |
| redshift-serverless-workgroups-should-prohibit-public-access | `aws_redshiftserverless_workgroup` | publicly_accessible=false | =true |
| redshift-serverless-namespaces-should-not-use-the-default-admin-username | `aws_redshiftserverless_namespace` | admin_username!=admin | =admin |
| redshift-serverless-namespaces-should-not-use-the-default-database-name | `aws_redshiftserverless_namespace` | db_name!=dev | =dev |
| redshift-serverless-namespaces-should-export-logs-to-cloudwatch-logs | `aws_redshiftserverless_namespace` | log_exports set | omitted |

### route53
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| route-53-public-hosted-zones-should-log-dns-queries | `aws_route53_query_log` | present for hosted zone | absent |

### s3
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| s3-block-public-access-account-level | `aws_s3_account_public_access_block` | all flags=true (toggle) | all flags=false (toggle) |
| s3-block-public-access-bucket-level | `aws_s3_bucket_public_access_block` | all flags=true | all flags=false |
| s3-bucket-block-public-read-access | `aws_s3_bucket_public_access_block` | block_public_acls=true | =false |
| s3-bucket-block-public-write-access | `aws_s3_bucket_public_access_block` | restrict_public_buckets=true | =false |
| s3-require-ssl | `aws_s3_bucket_policy` | deny if aws:SecureTransport=false | no SSL condition |
| s3-bucket-policy-restrict-access-to-other-accounts | `aws_s3_bucket_policy` | condition restricts to org/account | allows cross-account |
| s3-access-point-block-public-access-enabled | `aws_s3_access_point` | public_access_block_configuration all=true | all=false |
| s3-multi-region-access-points-should-have-block-public-access-settings-enabled | `aws_s3_multi_region_access_point` | public_access_block all=true | all=false |

CIS additions: MFA delete (CIS-2.1.2 via `mfa_delete="Enabled"`/`"Disabled"`), server access logging (CIS via `aws_s3_bucket_logging`).

### sagemaker
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| sagemaker-notebook-no-direct-internet-access | `aws_sagemaker_notebook_instance` | direct_internet_access=Disabled | =Enabled |
| sagemaker-notebook-instances-should-be-launched-in-a-custom-vpc | `aws_sagemaker_notebook_instance` | subnet_id set | omitted |
| sagemaker-notebook-instance-root-access-check | `aws_sagemaker_notebook_instance` | root_access=Disabled | =Enabled |
| sagemaker-endpoint-config-prod-instance-count-check | `aws_sagemaker_endpoint_configuration` | initial_instance_count>1 | =1 |
| sagemaker-models-should-block-inbound-traffic | `aws_sagemaker_model` | enable_network_isolation=true | =false |
| sagemaker-notebook-ensure-subnet-id-for-instance | `aws_sagemaker_notebook_instance` | subnet_id set | omitted |
| sagemaker-notebook-instances-should-run-on-supported-platforms | `aws_sagemaker_notebook_instance` | platform_identifier=notebook-al2-v2 | old platform |

### secretsmanager
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| secretsmanager-auto-rotation-enabled-check | `aws_secretsmanager_secret_rotation` | rotation enabled | absent |

### servicecatalog
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| service-catalog-shared-within-organization-only | `aws_servicecatalog_portfolio_share` | type=ORGANIZATION | type=ACCOUNT (external) |

### sns
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| sns-topic-access-policies-should-not-allow-public-access | `aws_sns_topic_policy` | principal restricted to account | principal=* |

### sqs
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| sqs-queue-should-be-encrypted-at-rest | `aws_sqs_queue` | sqs_managed_sse_enabled=true | no encryption |
| sqs-queue-block-public-access | `aws_sqs_queue_policy` | principal restricted to account | principal=* |

### ssm
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| ssm-documents-should-not-be-public | `aws_ssm_document` | permissions not public | permissions public |

### stepfunction
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| step-functions-state-machine-logging-enabled | `aws_sfn_state_machine` | logging_configuration.level=ERROR | =OFF |

### transfer
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| transfer-family-server-should-not-use-ftp | `aws_transfer_server` | protocols=[SFTP] | protocols=[FTP] |
| transfer-family-connectors-should-have-logging-enabled | `aws_transfer_connector` | logging_role set | omitted |

### waf
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| waf-classic-logging-enabled | `aws_waf_web_acl` | logging_configuration set | absent |
| waf-global-rule-not-empty | `aws_waf_rule` | predicates set | empty |
| waf-global-rulegroup-not-empty | `aws_waf_rule_group` | activated_rules set | empty |
| waf-global-webacl-not-empty | `aws_waf_web_acl` | rules set | empty |
| waf-regional-rule-not-empty | `aws_wafregional_rule` | predicates set | empty |
| waf-regional-rulegroup-not-empty | `aws_wafregional_rule_group` | activated_rules set | empty |
| waf-regional-webacl-not-empty | `aws_wafregional_web_acl` | rules set | empty |
| wafv2-webacl-not-empty | `aws_wafv2_web_acl` | rule set | empty |
| wafv2-rulegroup-logging-enabled | `aws_wafv2_web_acl_logging_configuration` | present | absent |

### workspaces
| Policy | Resource | Pass | Fail |
|--------|----------|------|------|
| workspaces-root-volumes-should-be-encrypted-at-rest | `aws_workspaces_workspace` | root_volume_encryption_enabled=true | =false |
| workspaces-user-volumes-should-be-encrypted-at-rest | `aws_workspaces_workspace` | user_volume_encryption_enabled=true | =false |

---

## Controls Not Exercisable via Terraform

These controls exist in the policy library but cannot be meaningfully tested
through Terraform plan/apply. They require out-of-band validation:

| Control | Reason |
|---------|--------|
| `ec2-ebs-snapshot-public-restorable-check-account-level` | Account-level attribute, not a Terraform resource |
| Root account MFA (CIS-1.4, CIS-1.5, IAM.6) | Root credentials not manageable by Terraform |
| Root account access keys (CIS-1.3, IAM.4) | Cannot create/delete via Terraform |
| IAM.3 / CIS-1.13 — access key age | Key creation date is set at creation; cannot simulate old key |
| IAM.8 — unused credentials | Requires usage history, not a resource attribute |
| SSM.2/3 — patch/association compliance | Runtime compliance state, not Terraform-manageable |

---

## Workload Archetype

Resources are grounded in a mixed production environment to give all attributes
realistic context:

- **Web app tier**: ALB → ECS/EKS → RDS (Aurora) + ElastiCache + S3 + CloudFront + WAF + ACM + API Gateway
- **Data platform tier**: S3 → Kinesis → MSK → Redshift + DynamoDB + Glue + EMR + Neptune
- **Container platform tier**: ECR → ECS + EKS → Lambda + Step Functions + EventBridge + Secrets Manager

---

## Implementation Phases

### Phase 1 — Core scaffold + highest-signal modules
`versions.tf`, `provider.tf`, `backend.tf`, `variables.tf`, `outputs.tf`, `main.tf`
Modules: `iam`, `s3`, `ec2`, `cloudtrail`, `kms`, `rds`, `eks`, `ecs`, `elb`, `lambda`

### Phase 2 — Data services
`redshift`, `redshiftserverless`, `dynamo-db`, `kinesis`, `opensearch`, `elasticsearch`, `msk`, `neptune`, `docdb`

### Phase 3 — Network + security services
`waf`, `cloudfront`, `network-firewall`, `guardduty`, `inspector`, `macie`, `secretsmanager`, `sqs`, `sns`

### Phase 4 — Compute + container + app services
`ecr`, `efs`, `elasticache`, `autoscaling-group`, `api-gateway`, `lambda` (remaining), `stepfunction`, `eventbridge`, `backup`

### Phase 5 — Specialist services
`acm`, `appsync`, `athena`, `codebuild`, `connect`, `datasync`, `dms`, `elasticbeanstalk`, `emr`, `fsx`, `glue`, `kinesis`, `macie`, `mq`, `route53`, `sagemaker`, `servicecatalog`, `ssm`, `transfer`, `workspaces`

---

## Notes

- **AWS account**: dedicated sandbox, no other workloads
- **Apply/destroy**: full apply every test run, destroy immediately after
- **Cost**: tag all instances with `AutoShutdown = "true"`. Estimated cost per full run: ~$15–25 (dominated by EKS, RDS multi-AZ, Redshift)
- **Region**: `us-east-1` default, override via `aws_region`
- **State**: HCP Terraform, remote execution, single workspace `security-controls-regression`
- **Terraform**: `>= 1.9.0` | **AWS provider**: `~> 5.0`
