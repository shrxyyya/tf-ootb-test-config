# ---------------------------------------------------------------------------
# modules/cloudfront/main.tf
#
# Security controls covered:
#   CloudFront.1  — cloudfront-should-have-default-root-object-configured
#   CloudFront.3  — cloudfront-should-require-encryption-in-transit
#   CloudFront.5  — cloudfront-distributions-should-have-logging-enabled
#   CloudFront.6  — cloudfront-associated-with-waf
#   CloudFront.8  — cloudfront-distributions-should-use-sni-to-serve-https-requests
#   CloudFront.10 — cloudfront-distributions-should-not-use-deprecated-ssl-protocols
#   CloudFront.13 — cloudfront-s3-origin-access-control-enabled
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# S3 origin bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "origin" {
  bucket = "regression-test-cf-origin-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "regression-test-cf-origin"
  })
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket = aws_s3_bucket.origin.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "origin" {
  bucket = aws_s3_bucket.origin.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# CloudFront Origin Access Control
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "regression-test-oac"
  description                       = "OAC for regression-test CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "origin_oac" {
  statement {
    sid       = "AllowCloudFrontOAC"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.origin.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.pass.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "origin" {
  bucket     = aws_s3_bucket.origin.id
  policy     = data.aws_iam_policy_document.origin_oac.json
  depends_on = [aws_s3_bucket_public_access_block.origin]
}

# ---------------------------------------------------------------------------
# Pass distribution — all controls satisfied
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "pass" {
  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = var.wafv2_web_acl_arn
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  logging_config {
    bucket          = "${var.logs_bucket_id}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront/"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# CloudFront.1 fail — no default_root_object
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "root_object_fail" {
  count = var.create_failing_resources ? 1 : 0

  enabled             = true
  default_root_object = "" # intentional violation
  web_acl_id          = var.wafv2_web_acl_arn
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  logging_config {
    bucket          = "${var.logs_bucket_id}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront-root-fail/"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "CloudFront.1"
  })
}

# ---------------------------------------------------------------------------
# CloudFront.3 fail — viewer_protocol_policy = allow-all
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "https_fail" {
  count = var.create_failing_resources ? 1 : 0

  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = var.wafv2_web_acl_arn
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "allow-all" # intentional violation
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  logging_config {
    bucket          = "${var.logs_bucket_id}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront-https-fail/"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "CloudFront.3"
  })
}

# ---------------------------------------------------------------------------
# CloudFront.5 fail — no logging_config
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "logging_fail" {
  count = var.create_failing_resources ? 1 : 0

  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = var.wafv2_web_acl_arn
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  # No logging_config — intentional violation for CloudFront.5

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "CloudFront.5"
  })
}

# ---------------------------------------------------------------------------
# CloudFront.6 fail — no web_acl_id
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "waf_fail" {
  count = var.create_failing_resources ? 1 : 0

  enabled             = true
  default_root_object = "index.html"
  # No web_acl_id — intentional violation
  price_class = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  logging_config {
    bucket          = "${var.logs_bucket_id}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront-waf-fail/"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "CloudFront.6"
  })
}

# ---------------------------------------------------------------------------
# CloudFront.13 fail — origin without origin_access_control_id
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "oac_fail" {
  count = var.create_failing_resources ? 1 : 0

  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = var.wafv2_web_acl_arn
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id   = "s3-origin"
    # No origin_access_control_id — intentional violation for CloudFront.13
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  logging_config {
    bucket          = "${var.logs_bucket_id}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront-oac-fail/"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "CloudFront.13"
  })
}

# ---------------------------------------------------------------------------
# CloudFront.10 fail — deprecated TLS protocol (TLSv1)
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "ssl_protocol_fail" {
  count = var.create_failing_resources ? 1 : 0

  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = var.wafv2_web_acl_arn
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = null
    minimum_protocol_version       = "TLSv1" # intentional violation: deprecated protocol
    ssl_support_method             = "sni-only"
  }

  logging_config {
    bucket          = "${var.logs_bucket_id}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront-ssl-fail/"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "CloudFront.10"
  })
}

# ---------------------------------------------------------------------------
# CloudFront.8 fail — ssl_support_method = vip (not SNI)
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "sni_fail" {
  count = var.create_failing_resources ? 1 : 0

  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = var.wafv2_web_acl_arn
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = null
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "vip" # intentional violation: not SNI
  }

  logging_config {
    bucket          = "${var.logs_bucket_id}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront-sni-fail/"
  }

  tags = merge(var.tags, {
    compliance_test = "intentional_violation"
    controls        = "CloudFront.8"
  })
}
