locals {
  t = var.thresholds

  log_metrics_namespace = "Microservices/Logs/${var.name_prefix}"

  redis_clusters = { for index, id in var.redis_cluster_ids : tostring(index) => id }
}

resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  for_each = var.services

  alarm_name          = "${var.name_prefix}-${each.key}-asg-cpu-high"
  alarm_description   = "${each.value.container_name} ASG average CPU above ${local.t.asg_cpu_percent}% for 5 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = local.t.asg_cpu_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    AutoScalingGroupName = each.value.asg_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "asg_memory_high" {
  for_each = var.services

  alarm_name          = "${var.name_prefix}-${each.key}-asg-memory-high"
  alarm_description   = "${each.value.container_name} ASG average memory above ${local.t.asg_memory_percent}%"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.asg_memory_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    AutoScalingGroupName = each.value.asg_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "asg_disk_high" {
  for_each = var.services

  alarm_name          = "${var.name_prefix}-${each.key}-asg-disk-high"
  alarm_description   = "${each.value.container_name} root disk usage above ${local.t.asg_disk_percent}%"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.asg_disk_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    AutoScalingGroupName = each.value.asg_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "tg_unhealthy_hosts" {
  for_each = var.services

  alarm_name          = "${var.name_prefix}-${each.key}-tg-unhealthy"
  alarm_description   = "${each.value.container_name} TG has unhealthy targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    TargetGroup  = each.value.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix

  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "hikari_pool_high" {
  for_each = var.services

  alarm_name          = "${var.name_prefix}-${each.key}-hikari-pool-high"
  alarm_description   = "${each.value.container_name} Hikari pool usage above ${local.t.hikari_pool_percent}%"
  comparison_operator = "GreaterThanThreshold"
  threshold           = local.t.hikari_pool_percent
  evaluation_periods  = 3
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "usage"
    expression  = "100 * active / max"
    label       = "Hikari pool usage %"
    return_data = true
  }

  dynamic "metric_query" {
    for_each = {
      active = "hikaricp.connections.active.value"
      max    = "hikaricp.connections.max.value"
    }

    content {
      id = metric_query.key
      metric {
        namespace   = var.metrics_namespace
        metric_name = metric_query.value
        period      = 60
        stat        = "Maximum"
        dimensions = {
          service     = each.value.container_name
          environment = var.environment
          pool        = "HikariPool-1"
        }
      }
    }
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  for_each = var.services

  name           = "${var.name_prefix}-${each.value.container_name}-errors"
  log_group_name = each.value.log_group_name
  pattern        = "\"ERROR\""

  metric_transformation {
    name          = "${each.value.container_name}-errors-count"
    namespace     = local.log_metrics_namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_log_errors_high" {
  for_each = var.services

  alarm_name          = "${var.name_prefix}-${each.value.container_name}-log-errors-high"
  alarm_description   = "${each.value.container_name} logged more than ${local.t.log_errors_count} ERROR lines in 5 minutes"
  namespace           = local.log_metrics_namespace
  metric_name         = aws_cloudwatch_log_metric_filter.app_errors[each.key].metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = local.t.log_errors_count
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  for_each = var.databases

  alarm_name          = "${var.name_prefix}-${each.key}-db-cpu-high"
  alarm_description   = "${each.value} CPU above ${local.t.rds_cpu_percent}%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.rds_cpu_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "db_connections_high" {
  for_each = var.databases

  alarm_name          = "${var.name_prefix}-${each.key}-db-connection-high"
  alarm_description   = "${each.value} DB connections above ${local.t.rds_connections}"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.rds_connections
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "db_free_storage_low" {
  for_each = var.databases

  alarm_name          = "${var.name_prefix}-${each.key}-db-free-storage-low"
  alarm_description   = "${each.value} FreeStorageSpace below ${local.t.rds_free_storage_bytes} bytes"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.rds_free_storage_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "${var.name_prefix}-alb-5xx-high"
  alarm_description   = "Targets returned more than ${local.t.alb_5xx_count} 5xx responses in 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = local.t.alb_5xx_count
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "${var.name_prefix}-alb-latency-high"
  alarm_description   = "ALB p95 target response time above ${local.t.alb_p95_latency_sec}s"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.alb_p95_latency_sec
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}


resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  for_each = local.redis_clusters

  alarm_name          = "${var.name_prefix}-redis-${each.key}-cpu-high"
  alarm_description   = "Redis node ${each.value} CPU above ${local.t.redis_cpu_percent}%"
  namespace           = "AWS/ElastiCache"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.redis_cpu_percent
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    CacheClusterId = each.value
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "redis_memory_high" {
  for_each = local.redis_clusters

  alarm_name          = "${var.name_prefix}-redis-${each.key}-memory-high"
  alarm_description   = "Redis node ${each.value} memory usage above ${local.t.redis_memory_percent}%"
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = local.t.redis_memory_percent
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    CacheClusterId = each.value
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
