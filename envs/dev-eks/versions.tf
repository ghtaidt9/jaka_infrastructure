terraform {
  # use_lockfile (s3-native state locking) needs >= 1.10
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # terraform-aws-modules/eks v21 needs aws >= 6
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  # Partial config - the rest comes from backend.hcl:
  #  terraform init -backend-config backend.hcl
  backend "s3" {}
}
