# Security Controls Regression Test Suite

Terraform HCL fixture that provisions paired pass and fail AWS infrastructure across 54 service modules. Used to regression-test Sentinel and Terraform compliance policies against the AWS Foundational Security Best Practices (FSBP) standard and CIS AWS Foundations Benchmark v5.0.0. Requires a real `terraform apply` against an AWS account so policies can be evaluated at all three phases: `plan`, `apply`, and `state`.

## Prerequisites

- Terraform >= 1.9.0
- AWS credentials with broad provisioning permissions (AdministratorAccess or equivalent)
- HCP Terraform organization (workspace configured in `backend.tf`)

## Quick Start

```bash
terraform init
terraform apply                          # deploy with failing resources (default)
terraform destroy                        # tear down everything
```

Override the region or toggle mode via `-var`:

```bash
terraform apply -var="aws_region=us-west-2"
terraform apply -var="create_failing_resources=false"
```

## Test Modes

| Variable | Value | Effect |
|---|---|---|
| `create_failing_resources` | `true` (default) | Singleton account-level resources deploy in their **non-compliant** configuration. Policies should fire. |
| `create_failing_resources` | `false` | Singleton resources deploy in their **compliant** configuration. Policies should produce zero findings. |

Non-singleton resources always deploy both a pass resource and a fail resource in the same apply. Only singleton resources (one per account) are toggle-driven.

## Intentional Violations

Every fail resource is tagged:

```hcl
compliance_test = "intentional_violation"
```

Sentinel and Terraform compliance policies use this tag to exempt known-bad resources from alerting in CI, while still asserting that the violation is detectable.

## Module Coverage

| Module | Controls covered |
|---|---|
| `acm` | ACM.1 — certificate renewal |
| `api-gateway` | APIGateway.1–9 — logging, WAF, TLS, access control |
| `appsync` | AppSync.1–6 — logging, WAF, cache encryption |
| `athena` | Athena.1 — workgroup result encryption |
| `autoscaling-group` | AutoScaling.1–9 — ELB health checks, IMDSv2, EBS encryption |
| `backup` | Backup.1 — recovery point encryption |
| `cloudfront` | CloudFront.1–13 — HTTPS, WAF, logging, geo restriction |
| `cloudtrail` | CloudTrail.1–7, CIS-3.1–3.7 — multi-region, log validation, KMS, CloudWatch |
| `codebuild` | CodeBuild.1–7 — environment variables, logging, privileged mode |
| `connect` | Connect.1–2 — instance storage, flow logs |
| `datasync` | DataSync.1 — task logging |
| `dms` | DMS.1, DMS.6–9 — replication encryption, auto upgrade |
| `docdb` | DocumentDB.1–5 — encryption, audit logs, deletion protection |
| `dynamo-db` | DynamoDB.1–7 — CMK encryption, PITR, DAX TLS |
| `ec2` | EC2.1–51 — IMDSv2, SGs, EBS encryption, flow logs, snapshots |
| `ecr` | ECR.1–3 — image scanning, immutable tags, KMS |
| `ecs` | ECS.1–12 — Fargate platform, task definitions, logging |
| `efs` | EFS.1–6 — encryption, access points, backup |
| `eks` | EKS.1–8 — endpoint access, secrets encryption, logging |
| `elasticache` | ElastiCache.1–10 — encryption in-transit/at-rest, auth tokens |
| `elasticbeanstalk` | ElasticBeanstalk.1–3 — managed updates, logging, IMDSv2 |
| `elasticsearch` | ES.1–8 — KMS, node-to-node, HTTPS, logging |
| `elb` | ELB.1–14 — HTTPS, access logs, deletion protection, desync |
| `emr` | EMR.1–2 — master/slave node public access, TLS |
| `eventbridge` | EventBridge.3–4 — dead-letter queues, cross-account |
| `fsx` | FSx.1 — FSx for Windows backup |
| `glue` | Glue.1–4 — job bookmarks, security config, S3 encryption |
| `guardduty` | GuardDuty.1–4 — detector enabled, S3/EKS/Lambda protection |
| `iam` | IAM.1–28, CIS-1.x — password policy, MFA, access keys, roles |
| `inspector` | Inspector.1–3 — EC2/ECR/Lambda scanning enabled |
| `kinesis` | Kinesis.1–3 — stream encryption, Firehose logging |
| `kms` | KMS.1–4, CIS-3.6 — key rotation, CMK usage |
| `lambda` | Lambda.1–5 — public access, VPC, encryption, tracing |
| `macie` | Macie.1 — Macie enabled |
| `mq` | MQ.1–7 — auto-minor-upgrade, audit/general logging, no public |
| `msk` | MSK.1–3 — encryption in-transit, client auth, logging |
| `neptune` | Neptune.1–8 — encryption, audit logs, deletion protection |
| `network-firewall` | NetworkFirewall.1–9 — deletion protection, logging, policy |
| `opensearch` | OpenSearch.1–11 — KMS, HTTPS, logging, access control |
| `rds` | RDS.1–36 — encryption, deletion protection, multi-AZ, logging |
| `redshift` | Redshift.1–15 — encryption, audit logging, snapshot retention |
| `redshiftserverless` | RedshiftServerless.1 — public endpoint |
| `route53` | Route53.1–2 — query logging, DNSSEC |
| `s3` | S3.1–19, CIS-2.1.x — public access, SSE, versioning, logging |
| `sagemaker` | SageMaker.1–6 — direct internet access, VPC, encryption |
| `secretsmanager` | SecretsManager.1–4 — auto-rotation, KMS, unused secrets |
| `servicecatalog` | ServiceCatalog.1 — S3 origin, shared portfolio |
| `sns` | SNS.1–2 — KMS encryption, access policy |
| `sqs` | SQS.1 — KMS encryption |
| `ssm` | SSM.1–4 — patch compliance, association status |
| `stepfunction` | StepFunctions.1 — logging enabled |
| `transfer` | Transfer.1–3 — logging, server auth, endpoint type |
| `waf` | WAF.1–10, WAFv2.1 — rules, logging, Firehose |
| `workspaces` | WorkSpaces.1–2 — volume encryption, running mode |

## Cost Estimate

A full apply runs roughly **\$8–15 USD/hour** depending on region, driven primarily by EKS cluster time (~\$0.10/hr), NAT gateway, RDS Multi-AZ instances, and MSK brokers. Destroy immediately after test runs to contain cost. EKS takes ~12 minutes to provision.

## Important Notes

- **Singleton resources** (IAM password policy, EBS default encryption, GuardDuty detector, Macie session, etc.) cannot have simultaneous pass and fail instances. Their compliance posture is controlled by `create_failing_resources`.
- **Route53** requires the `aws.us_east_1` provider alias. This is pre-wired in `provider.tf` and `main.tf`; no additional configuration is needed.
- **EKS** takes 10–15 minutes to reach `ACTIVE` state. Plan for this in CI pipeline timeouts.
- **MSK Connect** is disabled by default (`create_msk_connect = false`) to avoid provisioning a running cluster for a single control test.
- Never commit real credentials or passwords. The `db_password` variable defaults to a placeholder — override via environment variable (`TF_VAR_db_password`) or a gitignored `terraform.tfvars`.
