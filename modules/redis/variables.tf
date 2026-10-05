variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "description" {
  description = "Replication group description"
  type        = string
  default     = "Shared Redis cache for the microservices"
}

variable "private_subnet_ids" {
  description = "Private subnets for the cache subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the replication group"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN encrypting the AUTH-token secret"
  type        = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1" # matches redis:7-alpine in both services' docker-compose.yml
}

variable "node_type" {
  description = "Cache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "num_cache_clusters" {
  description = "Nodes in the replication group. 1 = no replica, no failover (dev); >= 2 turns on automatic failover + Multi-AZ"
  type        = number
  default     = 2

  validation {
    condition     = var.num_cache_clusters >= 1 && var.num_cache_clusters <= 6
    error_message = "num_cache_clusters must be between 1 and 6."
  }
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window of the AUTH-token secret. 0 = delete immediately"
  type        = number
  default     = 7
}
