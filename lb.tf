## lb
# alb
resource "aws_alb" "exapmle" {
  name                             = "example"
  load_balancer_type               = "application"
  internal                         = false
  idle_timeout                     = 60
  enable_cross_zone_load_balancing = true
  //enable_deletion_protection = true

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id
  ]

  access_logs {
    bucket  = aws_s3_bucket.alb_log.id
    enabled = true
  }

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id
  ]
}

# listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.exapmle.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは「HTTP」です"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_alb.exapmle.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.example.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは「HTTPS」です"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_alb.exapmle.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# target group
resource "aws_lb_target_group" "example" {
  name                 = "example"
  target_type          = "ip"
  vpc_id               = aws_vpc.example.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
    port                = "traffic-port" # 上記のportで指定したportと同じ
    protocol            = "HTTP"
  }

  depends_on = [aws_alb.exapmle]
}

# リスナールール
resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }

  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}

output "alb_dns_name" {
  value = aws_alb.exapmle.dns_name
}

# sg(module)
module "http_sg" {
  source      = "./security_group"
  name        = "http-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.example.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./security_group"
  name        = "http-redirect-sg"
  vpc_id      = aws_vpc.example.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

## route53
# 参照
data "aws_route53_zone" "example" {
  name = "exapmle.com"
  // ここにAWSコンソール上から登録したものを設定とかしちゃいなよyou
}

# 新規作成
/*
resource "aws_route53_zone" "test_example" {
  name = "test.example.com"
}
*/

# DNSレコード
resource "aws_route53_record" "example" {
  name    = data.aws_route53_zone.example.name
  zone_id = data.aws_route53_zone.example.zone_id
  type    = "A"

  alias {
    name                   = aws_alb.exapmle.dns_name
    zone_id                = aws_alb.exapmle.zone_id
    evaluate_target_health = true
  }
}

# SSL証明書
resource "aws_acm_certificate" "example" {
  domain_name               = aws_route53_record.example.name
  subject_alternative_names = []    # ドメイン名を追加したい時に使う
  validation_method         = "DNS" # ドメイン所有権の検証

  lifecycle {
    create_before_destroy = true
  }
}

# 検証用DNSレコード
resource "aws_route53_record" "example_certificate" {
  name    = aws_acm_certificate.example.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.example.domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.example.domain_validation_options[0].resource_record_value]
  zone_id = data.aws_route53_zone.example.id
  ttl     = 60
}

# SSL証明書の検証完了まで待つやーつ
resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.example.arn
  validation_record_fqdns = [aws_route53_record.example_certificate.fqdn]
}
