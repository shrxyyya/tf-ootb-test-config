terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# NOTE: FSx file systems are expensive. Minimum viable capacity is used.
# OpenZFS 64 GiB, Lustre 1200 GiB (minimum), ONTAP 1024 GiB, Windows 32 GiB.
# Destroy promptly after regression testing to contain cost.

# ---------------------------------------------------------------------------
# FSx.1 — fsx-openzfs-copy-tags-to-backups-and-volumes-enabled
# FSx.3 — fsx-openzfs-deployment-type-check (must be MULTI_AZ_1)
# Pass: copy_tags_to_backups/volumes = true, deployment_type = MULTI_AZ_1
# ---------------------------------------------------------------------------

resource "aws_fsx_openzfs_file_system" "pass" {
  storage_capacity    = 64
  subnet_ids          = slice(var.private_subnet_ids, 0, 2)
  deployment_type     = "MULTI_AZ_1"
  preferred_subnet_id = var.private_subnet_ids[0]
  throughput_capacity = 64
  kms_key_id          = var.kms_key_arn

  copy_tags_to_backups = true
  copy_tags_to_volumes = true

  tags = merge(var.tags, { Name = "regression-test-openzfs-pass" })
}

# ---------------------------------------------------------------------------
# FSx.1 — fail: copy_tags_to_backups = false, copy_tags_to_volumes = false
# ---------------------------------------------------------------------------

resource "aws_fsx_openzfs_file_system" "tags_fail" {
  count = var.create_failing_resources ? 1 : 0

  storage_capacity    = 64
  subnet_ids          = slice(var.private_subnet_ids, 0, 2)
  deployment_type     = "MULTI_AZ_1"
  preferred_subnet_id = var.private_subnet_ids[0]
  throughput_capacity = 64
  kms_key_id          = var.kms_key_arn

  copy_tags_to_backups = false # intentional violation
  copy_tags_to_volumes = false # intentional violation

  tags = merge(var.tags, {
    Name            = "regression-test-openzfs-tags-fail"
    compliance_test = "intentional_violation"
    controls        = "FSx.1"
  })
}

# ---------------------------------------------------------------------------
# FSx.3 — fail: deployment_type = SINGLE_AZ_1 (not MULTI_AZ)
# ---------------------------------------------------------------------------

resource "aws_fsx_openzfs_file_system" "singleaz_fail" {
  count = var.create_failing_resources ? 1 : 0

  storage_capacity    = 64
  subnet_ids          = [var.private_subnet_ids[0]]
  deployment_type     = "SINGLE_AZ_1" # intentional violation
  throughput_capacity = 64
  kms_key_id          = var.kms_key_arn

  copy_tags_to_backups = true
  copy_tags_to_volumes = true

  tags = merge(var.tags, {
    Name            = "regression-test-openzfs-singleaz-fail"
    compliance_test = "intentional_violation"
    controls        = "FSx.3"
  })
}

# ---------------------------------------------------------------------------
# FSx.2 — fsx-lustre-copy-tags-to-backups
# Pass: copy_tags_to_backups = true, PERSISTENT_2 deployment
# ---------------------------------------------------------------------------

resource "aws_fsx_lustre_file_system" "pass" {
  storage_capacity            = 1200
  subnet_ids                  = [var.private_subnet_ids[0]]
  deployment_type             = "PERSISTENT_2"
  per_unit_storage_throughput = 125
  kms_key_id                  = var.kms_key_arn
  copy_tags_to_backups        = true

  tags = merge(var.tags, { Name = "regression-test-lustre-pass" })
}

# ---------------------------------------------------------------------------
# FSx.2 — fail: copy_tags_to_backups = false
# ---------------------------------------------------------------------------

resource "aws_fsx_lustre_file_system" "tags_fail" {
  count = var.create_failing_resources ? 1 : 0

  storage_capacity            = 1200
  subnet_ids                  = [var.private_subnet_ids[0]]
  deployment_type             = "PERSISTENT_2"
  per_unit_storage_throughput = 125
  copy_tags_to_backups        = false # intentional violation

  tags = merge(var.tags, {
    Name            = "regression-test-lustre-tags-fail"
    compliance_test = "intentional_violation"
    controls        = "FSx.2"
  })
}

# ---------------------------------------------------------------------------
# FSx.4 — fsx-ontap-deployment-type-check (must be MULTI_AZ_1 or MULTI_AZ_2)
# NOTE: FSx ONTAP is expensive (~$0.10/GiB-month + throughput). Min config.
# Pass: MULTI_AZ_1 deployment
# ---------------------------------------------------------------------------

resource "aws_fsx_ontap_file_system" "pass" {
  storage_capacity    = 1024
  subnet_ids          = slice(var.private_subnet_ids, 0, 2)
  preferred_subnet_id = var.private_subnet_ids[0]
  deployment_type     = "MULTI_AZ_1"
  throughput_capacity = 128
  kms_key_id          = var.kms_key_arn

  tags = merge(var.tags, { Name = "regression-test-ontap-pass" })
}

# ---------------------------------------------------------------------------
# FSx.4 — fail: deployment_type = SINGLE_AZ_1
# ---------------------------------------------------------------------------

resource "aws_fsx_ontap_file_system" "singleaz_fail" {
  count = var.create_failing_resources ? 1 : 0

  storage_capacity    = 1024
  subnet_ids          = [var.private_subnet_ids[0]]
  preferred_subnet_id = var.private_subnet_ids[0]
  deployment_type     = "SINGLE_AZ_1" # intentional violation
  throughput_capacity = 128
  kms_key_id          = var.kms_key_arn

  tags = merge(var.tags, {
    Name            = "regression-test-ontap-singleaz-fail"
    compliance_test = "intentional_violation"
    controls        = "FSx.4"
  })
}

# ---------------------------------------------------------------------------
# FSx.5 — fsx-windows-deployment-type-check (must be MULTI_AZ_1)
# NOTE: FSx Windows requires an Active Directory — use self-managed AD config
# pointing to a placeholder DNS to avoid requiring an actual directory.
# This will fail to provision without a real AD; comment out if not needed.
# Pass: MULTI_AZ_2 deployment (satisfies multi-AZ requirement)
# ---------------------------------------------------------------------------

resource "aws_fsx_windows_file_system" "pass" {
  storage_capacity    = 32
  subnet_ids          = slice(var.private_subnet_ids, 0, 2)
  preferred_subnet_id = var.private_subnet_ids[0]
  deployment_type     = "MULTI_AZ_1"
  throughput_capacity = 8
  kms_key_id          = var.kms_key_arn

  self_managed_active_directory {
    dns_ips                                = ["10.0.1.10", "10.0.2.10"]
    domain_name                            = "regression.test.internal"
    username                               = "svc-fsx"
    password                               = "Ch@ngeMe2024!"
    organizational_unit_distinguished_name = "OU=FSx,DC=regression,DC=test,DC=internal"
  }

  tags = merge(var.tags, { Name = "regression-test-windows-pass" })
}

# ---------------------------------------------------------------------------
# FSx.5 — fail: deployment_type = SINGLE_AZ_1
# ---------------------------------------------------------------------------

resource "aws_fsx_windows_file_system" "singleaz_fail" {
  count = var.create_failing_resources ? 1 : 0

  storage_capacity    = 32
  subnet_ids          = [var.private_subnet_ids[0]]
  deployment_type     = "SINGLE_AZ_1" # intentional violation
  throughput_capacity = 8
  kms_key_id          = var.kms_key_arn

  self_managed_active_directory {
    dns_ips                                = ["10.0.1.10", "10.0.2.10"]
    domain_name                            = "regression.test.internal"
    username                               = "svc-fsx"
    password                               = "Ch@ngeMe2024!"
    organizational_unit_distinguished_name = "OU=FSx,DC=regression,DC=test,DC=internal"
  }

  tags = merge(var.tags, {
    Name            = "regression-test-windows-singleaz-fail"
    compliance_test = "intentional_violation"
    controls        = "FSx.5"
  })
}
