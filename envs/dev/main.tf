locals {
  project     = "jaka-mod"
  environment = "dev"
}

module "stack" {
  source = "../../stack"

  project     = local.project
  environment = local.environment

  azs                = ["${var.region}a", "${var.region}b"]
  single_nat_gateway = true

  instance_type = "t3.micro"
  ami_id        = var.ami_id
  image_tag     = var.image_tag

  asg = {
    min_size         = 1
    max_size         = 2
    desired_capacity = 1
  }

  postgres = {
    multi_az                = false
    backup_retention_period = 1
    skip_final_snapshot     = true
    deletion_protection     = false
  }

  redis = {
    num_cache_clusters = 1
  }

  s3_force_destroy               = true
  secret_recovery_window_in_days = 0
  log_retention_days             = 7

  alarm_email = var.alarm_email
}
