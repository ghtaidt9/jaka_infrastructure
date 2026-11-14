variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "github_owner" {
  description = "GitHub user/org that owns  the repo"
  type        = string
  default     = "ghtaidt9"
}

variable "app_repo" {
  description = "Name of the repo holding the 4 services"
  type        = string
  default     = "springboot_aws_compute_databases"
}