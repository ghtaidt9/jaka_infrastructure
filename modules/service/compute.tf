# Latest Ubuntu 22.04 AMI

data "aws_ami" "ubuntu" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_lb_target_group" "this" {
  name     = "${local.full_name}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled  = true
    path     = var.health_check_path
    protocol = "HTTP"
    port     = "traffic-port"

    # ~20s from app-up to receiving traffic (default 30s x 3 = 90s)
    interval          = 10
    healthy_threshold = 2
  }

  tags = {
    Name = "${local.full_name}-tg"
  }

}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.listener_arn
  priority     = var.listener_rule_priority

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Launch template
resource "aws_launch_template" "this" {
  name_prefix   = "${local.full_name}-lt-"
  image_id      = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = var.security_group_ids

  user_data = base64encode(templatefile("${path.module}/templates/service-bootstrap.sh.tpl", {
    region                = local.region
    ecr_registry          = local.ecr_registry
    image_repo            = aws_ecr_repository.this.repository_url
    image_tag_param       = aws_ssm_parameter.image_tag.name
    container_name        = local.container_name
    container_port        = aws_lb_target_group.this.port
    db_host               = var.database.host
    db_port               = var.database.port
    db_name               = var.database.name
    db_admin_username     = var.database.admin_username
    db_admin_secret_arn   = var.database.admin_secret_arn
    db_app_username       = var.database.app_username
    db_url_param          = var.database.url_parameter_name
    db_app_secret_arn     = var.database.app_secret_arn
    cw_ssm_parameter_name = aws_ssm_parameter.cloudwatch_agent_config.name
    redis_endpoint_param  = var.redis.primary_endpoint_parameter_name
    redis_port_param      = var.redis.port_parameter_name
    redis_auth_secret_arn = var.redis.auth_secret_arn
    redis_database_index  = var.redis.database_index
    environment           = var.environment
    metrics_namespace     = var.metrics_namespace
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = local.full_name
      SSMAccess = "true"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

resource "aws_autoscaling_group" "this" {
  name = "${local.full_name}-asg"

  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.this.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 300
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  tag {
    key                 = "Name"
    value               = "${local.full_name}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "SSMAccess"
    value               = "true"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                      = "${local.full_name}-cpu-target"
  autoscaling_group_name    = aws_autoscaling_group.this.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 180

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.asg_target_cpu
  }
}
