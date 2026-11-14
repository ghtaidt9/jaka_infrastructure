variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version, e.g. 1.35 (pick one in standard support)"
  type        = string
  default     = "1.35"
}
