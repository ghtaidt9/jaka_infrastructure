locals {
  dashboard_widgets = [
    {
      type = "metric", x = 0, y = 0, width = 12, height = 6
      properties = {
        title       = "ASG CPU Utilization"
        region      = local.region
        period      = 300
        stat        = "Average"
        view        = "timeSeries"
        annotations = { horizontal = [{ label = "CPU alarm threshold", value = local.t.asg_cpu_percent }] }
        metrics     = [for k, s in var.services : ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", s.asg_name, { label = s.container_name }]]
      }
    },
    {
      type = "metric", x = 12, y = 0, width = 12, height = 6
      properties = {
        title       = "CWAgent Memory Utilization"
        region      = local.region
        period      = 300
        stat        = "Average"
        view        = "timeSeries"
        annotations = { horizontal = [{ label = "Memory alarm threshold", value = local.t.asg_memory_percent }] }
        metrics     = [for k, s in var.services : ["CWAgent", "mem_used_percent", "AutoScalingGroupName", s.asg_name, { label = s.container_name }]]
      }
    },
    {
      type = "metric", x = 0, y = 6, width = 12, height = 6
      properties = {
        title       = "CWAgent Disk Utilization"
        region      = local.region
        period      = 300
        stat        = "Average"
        view        = "timeSeries"
        annotations = { horizontal = [{ label = "Disk alarm threshold", value = local.t.asg_disk_percent }] }
        metrics     = [for k, s in var.services : ["CWAgent", "disk_used_percent", "AutoScalingGroupName", s.asg_name, { label = s.container_name }]]
      }
    },
    {
      type = "metric", x = 12, y = 6, width = 12, height = 6
      properties = {
        title  = "ALB Errors and Latency"
        region = local.region
        period = 300
        view   = "timeSeries"
        metrics = [
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "target 5xx" }],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p95", label = "target p95 latency" }]
        ]
      }
    },
    {
      type = "metric", x = 0, y = 12, width = 12, height = 6
      properties = {
        title  = "RDS CPU and Connections"
        region = local.region
        period = 300
        stat   = "Average"
        view   = "timeSeries"
        metrics = concat(
          [for k, id in var.databases : ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id, { label = "${k} CPU" }]],
          [for k, id in var.databases : ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", id, { label = "${k} connections" }]]
        )
      }
    },
    {
      type = "metric", x = 12, y = 12, width = 12, height = 6
      properties = {
        title  = "Redis CPU and Memory"
        region = local.region
        period = 300
        stat   = "Average"
        view   = "timeSeries"
        metrics = concat(
          [for id in var.redis_cluster_ids : ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", id, { label = "${id} CPU" }]],
          [for id in var.redis_cluster_ids : ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", id, { label = "${id} memory" }]]
        )
      }
    },
    {
      type = "metric", x = 0, y = 18, width = 12, height = 6
      properties = {
        title  = "ALB Traffic"
        region = local.region
        period = 60
        view   = "timeSeries"
        metrics = [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "requests" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "target 4xx" }],
          ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "active connections" }]
        ]
      }
    },
    {
      type = "metric", x = 12, y = 18, width = 12, height = 6
      properties = {
        title  = "Target Group Health"
        region = local.region
        period = 60
        view   = "timeSeries"
        metrics = concat([
          for k, s in var.services : [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", s.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Minimum", label = "${k} healthy" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", s.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Maximum", label = "${k} unhealthy" }]
          ]
        ]...)
      }
    },
    {
      type = "metric", x = 0, y = 24, width = 12, height = 6
      properties = {
        title  = "RDS Latency and Free Storage"
        region = local.region
        period = 300
        stat   = "Average"
        view   = "timeSeries"
        metrics = concat(
          concat([
            for k, id in var.databases : [
              ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", id, { label = "${k} read latency (s)" }],
              ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", id, { label = "${k} write latency (s)" }]
            ]
          ]...),
          [for k, id in var.databases : ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", id, { label = "${k} free storage", yAxis = "right" }]]
        )
      }
    },
    {
      type = "metric", x = 12, y = 24, width = 12, height = 6
      properties = {
        title   = "Redis Cache Hit Rate"
        region  = local.region
        period  = 300
        stat    = "Average"
        view    = "timeSeries"
        metrics = [for id in var.redis_cluster_ids : ["AWS/ElastiCache", "CacheHitRate", "CacheClusterId", id, { label = "${id} hit rate %" }]]
      }
    },
    {
      type = "metric", x = 0, y = 30, width = 12, height = 6
      properties = {
        title  = "EC2 Disk I/O (bytes)"
        region = local.region
        period = 300
        stat   = "Sum"
        view   = "timeSeries"
        metrics = concat([
          for k, s in var.services : [
            ["CWAgent", "diskio_read_bytes", "AutoScalingGroupName", s.asg_name, { label = "${k} read" }],
            ["CWAgent", "diskio_write_bytes", "AutoScalingGroupName", s.asg_name, { label = "${k} write" }]
          ]
        ]...)
      }
    },
    {
      type = "metric", x = 12, y = 30, width = 12, height = 6
      properties = {
        title   = "Application ERROR log lines"
        region  = local.region
        period  = 300
        stat    = "Sum"
        view    = "timeSeries"
        metrics = [for k, s in var.services : [local.log_metrics_namespace, "${s.container_name}-errors-count", { label = s.container_name }]]
      }
    },
    {
      type = "log", x = 0, y = 36, width = 24, height = 6
      properties = {
        title  = "Latest ERROR log lines"
        region = local.region
        view   = "table"
        query  = "${join(" | ", [for s in values(var.services) : "SOURCE '${s.log_group_name}'"])} | fields @timestamp, @logStream, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50"
      }
    },
    {
      type = "metric", x = 0, y = 42, width = 24, height = 6
      properties = {
        title  = "App HTTP latency (avg ms) per service/uri"
        region = local.region
        period = 60
        view   = "timeSeries"
        metrics = [
          [{ expression = "SEARCH('Namespace=\"${var.metrics_namespace}\" MetricName=\"http.server.requests.avg\" environment=\"${var.environment}\"', 'Average', 60)", id = "e1", label = "" }]
        ]
      }
    },
  ]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-overview"
  dashboard_body = jsonencode({ widgets = local.dashboard_widgets })
}
