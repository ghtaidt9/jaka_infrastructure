data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  full_name      = "${var.name_prefix}-${var.service}"
  container_name = "${var.service}-service"

  region       = data.aws_region.current.name
  account_id   = data.aws_caller_identity.current.account_id
  ecr_registry = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"
}

# ECR repository
resource "aws_ecr_repository" "this" {
  name                 = "${local.full_name}-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after one day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep the ${var.ecr_keep_tagged_images} most recent version images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_keep_tagged_images
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Image tag the ASG boots. Terraform only seeds it; the deploy script owns it.
resource "aws_ssm_parameter" "image_tag" {
  name  = "/${var.name_prefix}/${var.service}-image-tag"
  type  = "String"
  value = var.image_tag

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "image_tag_previous" {
  name  = "/${var.name_prefix}/${var.service}-image-tag-previous"
  type  = "String"
  value = var.image_tag

  lifecycle {
    ignore_changes = [value]
  }
}

# Container logs + CloudWatch Agent config
resource "aws_cloudwatch_log_group" "app" {
  name              = "/microservice/${var.name_prefix}/${local.container_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name = "AmazonCloudWatch-${local.full_name}-service-agent-config"
  type = "String"
  value = templatefile("${path.module}/templates/cloudwatch-agent-config.json.tpl", {
    log_group_name  = aws_cloudwatch_log_group.app.name
    log_stream_name = "${local.container_name}/{instance_id}"
  })

  tags = {
    Name = "${local.full_name}-service-agent-config"
  }
}
