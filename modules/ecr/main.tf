# ECR repository
resource "aws_ecr_repository" "this" {
  for_each = var.services

  name                 = "${var.name_prefix}-${each.key}-service"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {

  for_each = var.services

  repository = aws_ecr_repository.this[each.key].name

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
        description  = "Keep the ${var.keep_tagged_images} most recent version images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = var.tag_prefixes
          countType     = "imageCountMoreThan"
          countNumber   = var.keep_tagged_images
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}