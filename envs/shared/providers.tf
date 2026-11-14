provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "jaka-mod"
      Environment = "shared"
      ManagedBy   = "Terraform"
    }
  }
}