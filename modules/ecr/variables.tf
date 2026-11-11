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
  description = "How many v* tagged images the ECR lifecycle policy keeps"
  type        = number
  default     = 10
}
