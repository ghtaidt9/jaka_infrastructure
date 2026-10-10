variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "alarm_email" {
  description = "Email subscribed to the alarm topic. null = no subscription"
  type        = string
  default     = null
}

variable "image_tag" {
  description = "Initial image tag for every service (the deploy script owns it afterwards)"
  type        = string
  default     = "latest"
}

variable "use_localstack" {
  description = "true when running against LocalStack (path-style s3, skip credential checks)"
  type        = bool
  default     = false
}

variable "ami_id" {
  description = "AMI for the service instances. null = latest Ubuntu 22.04; LocalStack needs an explicit ID"
  type        = string
  default     = null
}
