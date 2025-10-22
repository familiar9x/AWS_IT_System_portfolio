variable "name" { type = string }
variable "domain_name" { type = string }       # app.<base_domain>
variable "hosted_zone_name" { type = string }  # base_domain (e.g. example.com)
variable "cert_arn_use1" { type = string }     # ACM in us-east-1
variable "alb_dns_name" { type = string }      # ALB DNS name for /api/* origin
variable "api_gateway_domain" { type = string } # API Gateway domain for /ai/* origin

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

# Random secret for CloudFront to ALB communication
resource "random_password" "cf_secret" {
  length  = 32
  special = true
}

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

  # Origin 1: S3 Frontend (default behavior /*)
  origin {
    domain_name = aws_s3_bucket.fe.bucket_regional_domain_name
    origin_id   = "s3-fe"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Origin 2: ALB for API (/api/*)
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-api"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-From-CF"
      value = random_password.cf_secret.result
    }
  }

  # Origin 3: API Gateway for AI (/ai/*)
  origin {
    domain_name = var.api_gateway_domain
    origin_id   = "apigw-ai"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior: S3 Frontend
  default_cache_behavior {
    allowed_methods  = ["GET","HEAD","OPTIONS"]
    cached_methods   = ["GET","HEAD","OPTIONS"]
    target_origin_id = "s3-fe"
    viewer_protocol_policy = "redirect-to-https"
    compress = true
    
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
  }

  # Behavior 1: API paths (/api/*)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "alb-api"
    viewer_protocol_policy = "redirect-to-https"
    compress = true
    
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "775133bc-15f2-49f9-abea-afb2e0bf67d2" # Managed-AllViewerAndCloudFrontHeaders-2022-06
  }

  # Behavior 2: AI paths (/ai/*)
  ordered_cache_behavior {
    path_pattern     = "/ai/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "apigw-ai"
    viewer_protocol_policy = "redirect-to-https"
    compress = true
    
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "775133bc-15f2-49f9-abea-afb2e0bf67d2" # Managed-AllViewerAndCloudFrontHeaders-2022-06
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
output "cf_secret_header"  { value = random_password.cf_secret.result, sensitive = true }
