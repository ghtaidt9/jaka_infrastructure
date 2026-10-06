########################
# Identity
########################

variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "environment" {
  description = "Environment name, passed to the app as a metrics tag"
  type        = string
}

variable "service" {
  description = "Short service name, e.g. order. Container is <service>-service, S3 prefix is <service>s/"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.service))
    error_message = "service must be lowercase letters/digits, e.g. order."
  }
}

########################
# Routing
########################

variable "container_port" {
  description = "Port the Spring Boot container listens on (also the target group port)"
  type        = number
}

variable "health_check_path" {
  description = "ALB health check path, e.g. /api/orders/actuator/health"
  type        = string
}

variable "path_patterns" {
  description = "ALB path patterns routed to this service, e.g. [\"/api/orders\", \"/api/orders/*\"]"
  type        = list(string)
}

variable "listener_arn" {
  description = "ALB listener the path rule is attached to"
  type        = string
}

variable "listener_rule_priority" {
  description = "Priority of this service's listener rule (unique per listener)"
  type        = number
}

########################
# Compute
########################

variable "vpc_id" {
  description = "VPC of the target group"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets the ASG launches into"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI to boot. null = latest Canonical Ubuntu 22.04 amd64 (set it explicitly for LocalStack)"
  type        = string
  default     = null
}

variable "asg_min_size" {
  description = "ASG minimum size"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "ASG maximum size"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity at creation (ignored afterwards; the scaling policy owns it)"
  type        = number
  default     = 2
}

variable "asg_target_cpu" {
  description = "Target average CPU percent of the target-tracking scaling policy"
  type        = number
  default     = 60
}

########################
# Image / deploy
########################

variable "image_tag" {
  description = "Initial image tag written to the image-tag SSM parameter; afterwards the deploy script owns the value"
  type        = string
  default     = "latest"
}

variable "ecr_keep_tagged_images" {
  description = "How many v* tagged images the ECR lifecycle policy keeps"
  type        = number
  default     = 10
}

########################
# Dependencies
########################

variable "database" {
  description = "Connection info from the postgres module"
  type = object({
    host               = string
    port               = number
    name               = string
    admin_username     = string
    admin_secret_arn   = string
    app_username       = string
    app_secret_arn     = string
    url_parameter_name = string
  })
}

variable "redis" {
  description = "Connection info from the redis module. database_index keeps each service's keys apart"
  type = object({
    primary_endpoint_parameter_name = string
    port_parameter_name             = string
    auth_secret_arn                 = string
    database_index                  = number
  })
}

variable "kms_key_arn" {
  description = "KMS key the instance may use to decrypt its secrets"
  type        = string
}

variable "s3_bucket_arn" {
  description = "Shared bucket; the service may only touch objects under <service>s/"
  type        = string
}

########################
# Observability
########################

variable "metrics_namespace" {
  description = "CloudWatch namespace the app publishes Micrometer metrics to"
  type        = string
  default     = "Microservices/App"
}

variable "log_retention_days" {
  description = "Retention of the container log group"
  type        = number
  default     = 7
}
