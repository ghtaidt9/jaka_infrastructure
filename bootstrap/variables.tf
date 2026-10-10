variable "project" {
  description = "Project name, prefix of the state bucket"
  type        = string
  default     = "jaka-mod"
}

variable "region" {
  description = "Region of the state bucket"
  type        = string
  default     = "ap-southeast-1"
}

variable "use_localstack" {
  description = "true when running against LocalStack"
  type        = bool
  default     = false
}
