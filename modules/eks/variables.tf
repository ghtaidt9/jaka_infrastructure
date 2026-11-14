variable "name_prefix" {
  description = "Prefix for very resource name, e.g. jaka-mod-dev-eks"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version, e.g. 1.35 (pick one in standard support)"
  type        = string
  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must look like 1.35."
  }
}

variable "vpc_id" {
  description = "VPC of the cluster, from module.network"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the nodes, from module.network"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS needs subnets in at least 2 AZs."
  }
}

variable "node_instance_type" {
  description = "EC2 instance type of the managed node group"
  type        = string
  default     = "t3.medium"
}

variable "node_min" {
  description = "Minimum (and inital) node count of the managed node group"
  type        = number

  validation {
    condition     = var.node_min >= 2
    error_message = "At least 2 nodes are required to survive losing one AZ."
  }
}

variable "node_max" {
  description = "Maximum node count of the managed node group"
  type        = number

  validation {
    condition     = var.node_max >= var.node_min
    error_message = "node_max must be >= node_min."
  }
}