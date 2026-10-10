variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "environment" {
  description = "Environment tag the apps attach to their Micrometer metrics"
  type        = string
}

variable "alarm_email" {
  description = "Email subscribed to the alarm topic (must confirm the subscription). null = no subscription"
  type        = string
  default     = null
}

variable "metrics_namespace" {
  description = "CloudWatch namespace the apps publish Micrometer metrics to"
  type        = string
  default     = "Microservices/App"
}

variable "services" {
  description = "Per-service monitoring targets from the service module, keyed by short name (order, payment, ...)"
  type = map(object({
    container_name          = string
    asg_name                = string
    target_group_arn_suffix = string
    log_group_name          = string
  }))
}

variable "databases" {
  description = "RDS instance identifiers, keyed by short service name"
  type        = map(string)
}

variable "redis_cluster_ids" {
  description = "ElastiCache member cluster IDs"
  type        = list(string)
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (LoadBalancer dimension)"
  type        = string
}

variable "thresholds" {
  description = "Alarm thresholds; every field has a default"
  type = object({
    asg_cpu_percent        = optional(number, 70)
    asg_memory_percent     = optional(number, 80)
    asg_disk_percent       = optional(number, 80)
    rds_cpu_percent        = optional(number, 75)
    rds_connections        = optional(number, 80)
    rds_free_storage_bytes = optional(number, 2147483648) # 2 GiB
    alb_5xx_count          = optional(number, 5)
    alb_p95_latency_sec    = optional(number, 2)
    redis_cpu_percent      = optional(number, 75)
    redis_memory_percent   = optional(number, 75)
    log_errors_count       = optional(number, 10)
    hikari_pool_percent    = optional(number, 90)
  })
  default = {}

  validation {
    condition     = var.thresholds.asg_disk_percent >= 50 && var.thresholds.asg_disk_percent <= 90
    error_message = "thresholds.asg_disk_percent must be between 50 and 90."
  }
}
