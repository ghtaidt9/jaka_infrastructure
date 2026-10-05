variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "service" {
  description = "Service that owns this database, e.g. order"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.service))
    error_message = "service must be lowercase letters/digits, e.g. order."
  }
}

variable "db_name" {
  description = "Initial database name, e.g. orders"
  type        = string
}

variable "admin_username" {
  description = "RDS master username, e.g. order_admin (password is RDS-managed)"
  type        = string
}

variable "app_username" {
  description = "Least-privilege login the app uses, e.g. order_user"
  type        = string

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]*$", var.app_username))
    error_message = "app_username must be a plain Postgres identifier (lowercase, digits, underscore)."
  }
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the instance"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID encrypting the RDS-managed admin secret"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN encrypting the app-user secret"
  type        = string
}

variable "engine_version" {
  description = "Postgres engine version, e.g. 16"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Run a synchronous standby in a second AZ"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Days to keep automated backups"
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on delete. true for dev/lab, false for prod"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Block deletion of the instance"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention of the exported postgresql log group"
  type        = number
  default     = 7
}

variable "admin_secret_rotation_days" {
  description = "Rotation interval of the RDS-managed admin secret"
  type        = number
  default     = 30
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window of the app-user secret. 0 = delete immediately (dev: lets destroy/apply reuse the name)"
  type        = number
  default     = 7
}
