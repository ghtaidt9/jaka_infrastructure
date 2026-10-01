variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jaka-mod-dev"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across (one public + one private subnet per AZ)"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 AZs are required (ALB, RDS Multi-AZ and ElastiCache failover all need 2)."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ, same order as azs"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs must have exactly one CIDR per AZ."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ, same order as azs"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs must have exactly one CIDR per AZ."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, dev); false = one NAT per AZ (HA, prod)"
  type        = bool
  default     = false
}

variable "app_port_range" {
  description = "Container ports the ALB may reach on the EC2 instances"
  type = object({
    from = number
    to   = number
  })
  default = {
    from = 8080
    to   = 8081
  }
}

variable "redis_port" {
  description = "ElastiCache Redis port open from the EC2 instances"
  type        = number
  default     = 6379
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into the EC2 instances. null = no SSH rule (instances are reached through SSM Session Manager)"
  type        = string
  default     = null
}
