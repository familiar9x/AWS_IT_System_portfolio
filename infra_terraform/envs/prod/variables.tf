variable "account_id" { type = string }
variable "region" { type = string }           # e.g., ap-southeast-1
variable "region_us_east_1" { type = string } # must be us-east-1 for CloudFront
variable "name" { type = string }             # stack prefix, e.g., cmdb
variable "base_domain" { type = string }      # example.com (must be a Route53 hosted zone)

# Certificates
variable "cloudfront_cert_arn" { type = string } # ACM in us-east-1 for app.<base_domain>
variable "alb_cert_arn" { type = string }        # ACM in primary region for api.<base_domain>

# DB
variable "db_username" { type = string }
variable "db_password" { type = string }

# Image tags
variable "api_image_tag" { type = string }
variable "ext1_image_tag" { type = string }
variable "ext2_image_tag" { type = string }

variable "tags" {
  type    = map(string)
  default = { Project = "CMDB" }
}
