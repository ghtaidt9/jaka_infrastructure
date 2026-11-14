variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "services" {
  description = "Short service name, e.g. order. Container is <service>-service, S3 prefix is <service>s/"
  type        = set(string)

  # validation {
  #   condition     = can(regex("^[a-z][a-z0-9]*$", var.service))
  #   error_message = "service must be lowercase letters/digits, e.g. order."
  # }
}


variable "keep_tagged_images" {
  description = "How many tagged images the ECR lifecycle policy keeps"
  type        = number
  default     = 10
}

variable "image_tag_mutability" {
  description = "MUTABLE allows overwriting tags; IMMUTABLE forbids it (used by CI)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE"
  }
}

variable "tag_prefixes" {
  description = "Tag prefixes kept by the lifecycle policy (rule 2)"
  type        = list(string)
  default     = ["v"]
}