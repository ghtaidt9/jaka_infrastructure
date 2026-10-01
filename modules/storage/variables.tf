variable "name_prefix" {
  description = "Prefix for every resource name, e.g, jaka-mod-dev"
  type        = string
}

variable "tiered_prefixes" {
  description = "Top-level object prefixes that get a lifecycle tiering rule, e.g. [\"order\",\"payment\"]"
  type        = list(string)
}

variable "force_destroy" {
  description = "Let terraform destroy delete a non-empty bucket. true for dev/lab, false for prod"
  type        = bool
  default     = false
}

variable "ia_transition_days" {
  description = "Days after object creation before transitioning to STANDARD_IA"
  type        = number
  default     = 30

  validation {
    condition     = var.ia_transition_days >= 30
    error_message = "S3 requires at least 30 days before a STANDARD_IA transition."
  }
}

variable "glacier_transition_days" {
  description = "Days after object creation before transitioning to GLACIER"
  type        = number
  default     = 90
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep noncurrent (old) object versions before permanent deletion"
  type        = number
  default     = 90
}
