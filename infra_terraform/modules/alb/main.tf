variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "cert_arn" { type = string }
variable "cf_secret_header" {
  type      = string
  sensitive = true
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_security_group" "alb" {
  name   = "${var.name}-alb-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "api" {
  name        = "${var.name}-tg-api"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path                = "/health"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }
  tags = var.tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn

  # Default action: Block direct access (403)
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Direct access not allowed"
      status_code  = "403"
    }
  }
}

# Rule 1: Block if X-From-CF header doesn't match (priority 100)
resource "aws_lb_listener_rule" "block_direct" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Direct access forbidden"
      status_code  = "403"
    }
  }

  condition {
    http_header {
      http_header_name = "X-From-CF"
      values           = ["*"]
    }
  }

  # This rule catches requests WITHOUT the header or with wrong value
  # The condition above will NOT match if header is missing
}

# Rule 2: Allow CloudFront requests with correct header (priority 200)
resource "aws_lb_listener_rule" "allow_cloudfront" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    http_header {
      http_header_name = "X-From-CF"
      values           = [var.cf_secret_header]
    }
  }
}

output "alb_dns" { value = aws_lb.this.dns_name }
output "alb_arn" { value = aws_lb.this.arn }
output "alb_sg_id" { value = aws_security_group.alb.id }
output "tg_api_arn" { value = aws_lb_target_group.api.arn }
output "listener_arn" { value = aws_lb_listener.https.arn }
