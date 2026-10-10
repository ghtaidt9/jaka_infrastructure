variable "project" {
  description = "Project name, first half of every resource name"
  type        = string
  default     = "jaka-mod"
}

variable "environment" {
  description = "Environment name, second half of every resource name"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or pro"
  }
}

variable "services" {
  description = "Microservices to deploy, keyed by short name. Adding an entry adds its DB, ASG, route, alarms and dashboard lines"
  type = map(object({
    container_port         = number
    listener_rule_priority = number
    db_name                = string
    redis_database_index   = number
  }))
  default = {
    order = {
      container_port         = 8080
      listener_rule_priority = 100
      db_name                = "orders"
      redis_database_index   = 0
    }
    payment = {
      container_port         = 8081
      listener_rule_priority = 200
      db_name                = "payments"
      redis_database_index   = 1
    }
  }

  validation {
    condition     = length(distinct([for s in values(var.services) : s.listener_rule_priority])) == length(var.services)
    error_message = "Every service needs a unique listener_rule_priority."
  }

  validation {
    condition     = length(distinct([for s in values(var.services) : s.redis_database_index])) == length(var.services)
    error_message = "Every service needs its own redis_database_index."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway instead of one per AZ"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type of the service ASGs"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI for the service instances. null = latest Ubuntu 22.04 (set it for LocalStack)"
  type        = string
  default     = null
}

variable "asg" {
  description = "Sizing of every service ASG"
  type = object({
    min_size         = number
    max_size         = number
    desired_capacity = number
    target_cpu       = optional(number, 60)
  })

  validation {
    condition     = var.asg.min_size <= var.asg.desired_capacity && var.asg.desired_capacity <= var.asg.max_size
    error_message = "asg must satisfy min_size <= desired_capacity <= max_size"
  }
}

variable "image_tag" {
  description = "Initial image tag for every service (the deploy script owns it afterwards)"
  type        = string
  default     = "latest"
}

variable "postgres" {
  description = "Settings applied to every service database"
  type = object({
    engine_version          = optional(string, "16")
    instance_class          = optional(string, "db.t3.micro")
    allocated_storage       = optional(number, 20)
    multi_az                = bool
    backup_retention_period = number
    skip_final_snapshot     = bool
    deletion_protection     = bool
  })
}

variable "redis" {
  description = "Shared Redis settings"
  type = object({
    engine_version     = optional(string, "7.1")
    node_type          = optional(string, "cache.t3.micro")
    num_cache_clusters = number
  })
}

variable "s3_force_destroy" {
  description = "Let terraform destroy delete the non-empty microservices bucket"
  type        = bool
  default     = false
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window of the app secrets. 0 = delete immediately (dev)"
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "Retention of container and RDS log groups"
  type        = number
  default     = 7
}

variable "alarm_email" {
  description = "Email subscribed to the alarm topic. null = no subscription"
  type        = string
  default     = null
}

variable "alarm_thresholds" {
  description = "Overrides for the observability module's alarm thresholds"
  type        = any
  default     = {}
}
