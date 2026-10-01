terraform {
  # use_lockfile (s3-native state locking) needs >= 1.10
  required_version = ">=1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
  }
  # Partial config - the rest comes from backend.hcl or backend.localstack.hcl:
  #  terraform init -backend-config backend.hcl
  backend "s3" {}
}
