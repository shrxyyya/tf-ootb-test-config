# Security Controls Regression Test Suite

A Terraform HCL test fixture that provisions paired compliant and non-compliant AWS infrastructure for regression testing of Sentinel and Terraform compliance policies against the AWS Foundational Security Best Practices (FSBP) standard and CIS AWS Foundations Benchmark v5.0.0.

## Language

**Control**: A single checkable security requirement from FSBP or CIS, identified by an ID (e.g. `EC2.8`, `CIS-3.1`). Controls are the unit of policy coverage.
_Avoid_: rule, check, finding, requirement

**Pass resource**: A Terraform resource whose attributes are fully compliant with the control(s) it exercises. All non-tested attributes are set to production-realistic values.
_Avoid_: compliant resource, good resource, golden resource

**Fail resource**: A Terraform resource with one intentional misconfiguration that causes a specific control to fire. All other attributes are set to production-realistic values identical to the pass resource.
_Avoid_: bad resource, broken resource, non-compliant resource

**Intentional violation**: The single attribute difference between a fail resource and its paired pass resource. Marked with `compliance_test = "intentional_violation"` tag so policies can exempt it.
_Avoid_: misconfiguration, defect, finding

**Singleton resource**: An AWS resource of which only one instance can exist per account (e.g. `aws_iam_account_password_policy`, `aws_ebs_encryption_by_default`). Singletons cannot have simultaneous pass and fail instances; they are toggle-driven.
_Avoid_: account-level resource, global resource

**Toggle**: The `create_failing_resources` variable. When `true` (default), singleton resources deploy in their non-compliant configuration. When `false`, they deploy in their compliant configuration.
_Avoid_: flag, switch, mode

**Workload archetype**: The simulated production environment that gives resources realistic context. This suite uses a mixed archetype: web app tier + data platform tier + container platform tier.
_Avoid_: scenario, environment type, stack type

**Policy evaluation phase**: One of three Sentinel execution points — `plan` (checks intended changes), `apply` (checks applied changes), `state` (checks current state). This suite targets all three phases, requiring full `terraform apply` against a real AWS account.
_Avoid_: check phase, run phase

**Service module**: A Terraform module under `modules/` corresponding to one AWS service family. Mirrors the directory structure of the HashiCorp FSBP policy library. Contains pass and fail resources for all controls in that service.
_Avoid_: service folder, control module, policy module
