variable "name" { type = string }
variable "domain_name" { type = string }       # app.<base_domain>
variable "hosted_zone_name" { type = string }  # base_domain (e.g. example.com)
variable "cert_arn_use1" { type = string }     # ACM in us-east-1

provider "aws" { alias="use1" }

resource "aws_s3_bucket" "fe" { bucket = "${var.name}-fe-${random_id.suffix.hex}" force_destroy = true }
resource "aws_s3_bucket_public_access_block" "fe" {
  bucket = aws_s3_bucket.fe.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "fe" { bucket = aws_s3_bucket.fe.id versioning_configuration { status="Enabled" } }

resource "random_id" "suffix" { byte_length = 4 }

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.name}-oac"
  description                       = "OAC for S3 private FE"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  aliases             = [var.domain_name]

  origin {
    domain_name = aws_s3_bucket.fe.bucket_regional_domain_name
    origin_id   = "s3-fe"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET","HEAD","OPTIONS"]
    cached_methods   = ["GET","HEAD","OPTIONS"]
    target_origin_id = "s3-fe"
    viewer_protocol_policy = "redirect-to-https"
    compress = true
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  custom_error_response {
    error_code = 403
    response_code = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code = 404
    response_code = 200
    response_page_path = "/index.html"
  }

  price_class = "PriceClass_100"
  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate { acm_certificate_arn = var.cert_arn_use1, ssl_support_method = "sni-only", minimum_protocol_version = "TLSv1.2_2021" }
}

data "aws_route53_zone" "zone" { name = var.hosted_zone_name }

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# S3 bucket policy to allow CloudFront OAC
data "aws_iam_policy_document" "bucket" {
  statement {
    principals { type = "Service", identifiers = ["cloudfront.amazonaws.com"] }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.fe.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}
resource "aws_s3_bucket_policy" "fe" {
  bucket = aws_s3_bucket.fe.id
  policy = data.aws_iam_policy_document.bucket.json
}

output "bucket_name"       { value = aws_s3_bucket.fe.bucket }
output "distribution_id"   { value = aws_cloudfront_distribution.this.id }
output "distribution_host" { value = aws_cloudfront_distribution.this.domain_name }
