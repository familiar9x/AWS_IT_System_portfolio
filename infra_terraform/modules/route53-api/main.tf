variable "record_name" { type = string }      # api.<base_domain>
variable "hosted_zone_name" { type = string } # example.com
variable "alb_dns" { type = string }
variable "alb_zone_id" { type = string }

data "aws_route53_zone" "zone" { name = var.hosted_zone_name }
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.record_name
  type    = "A"
  alias {
    name                   = var.alb_dns
    zone_id                = var.alb_zone_id
    evaluate_target_health = false
  }
}
