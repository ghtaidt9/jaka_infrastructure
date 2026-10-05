variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "security_group_id" {
  description = "Security group attached to the ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets the ALB spans (at least 2 AZs)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An ALB needs subnets in at least 2 AZs"
  }
}
