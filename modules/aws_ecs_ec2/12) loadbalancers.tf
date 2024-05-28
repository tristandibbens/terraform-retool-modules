resource "aws_lb" "this" {
  name         = "${var.deployment_name}-alb"
  idle_timeout = var.alb_idle_timeout

  security_groups = [aws_security_group.alb.id]
  subnets         = var.lb_subnet_ids
  tags = var.tags
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = var.alb_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  tags = var.tags
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  name                 = "${var.deployment_name}-target"
  vpc_id               = var.vpc_id
  deregistration_delay = 30
  port                 = 3000
  protocol             = "HTTP"

  health_check {
    path                = "/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,302" #responses checked
  }
  tags = var.tags
}