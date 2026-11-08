terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50" # dev pins 5.x, dev-eks pins 6.x
    }
  }
}
