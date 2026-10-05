resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [var.security_group_id]
  subnets         = var.public_subnet_ids

  drop_invalid_header_fields = true

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({ error = "no route" })
      status_code  = "404"
    }
  }
}
