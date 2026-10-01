variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the secrets KMS key is deleted (7-30)"
  type        = number
  default     = 7

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30"
  }
}

variable "create_ssm_caller_user" {
  description = "Create the IAM user that may open SSM session on the service instances"
  type        = bool
  default     = true
}
