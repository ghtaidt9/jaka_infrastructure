locals {
  readable_parameter_arns = [
    for name in [
      aws_ssm_parameter.image_tag.name,
      var.database.url_parameter_name,
      var.redis.primary_endpoint_parameter_name,
      var.redis.port_parameter_name,
    ] : "arn:aws:ssm:${local.region}:${local.account_id}:parameter${name}"
  ]

  readable_secret_arns = [
    var.database.app_secret_arn,
    var.database.admin_secret_arn,
    var.redis.auth_secret_arn,
  ]

  managed_policy_arns = {
    ssm_core         = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ecr_readonly     = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    cloudwatch_agent = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  s3_prefix = "${var.service}s"
}

resource "aws_iam_role" "app" {
  name = "${local.full_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_policy" "app_access" {
  name        = "${local.full_name}-app-access"
  description = "Parameters, secrets and S3 prefix that ${local.container_name} (and only it) may read"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "ReadOwnParameters"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = local.readable_parameter_arns
      },
      {
        Sid      = "ReadOwnSecrets"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = local.readable_secret_arns
      },
      {
        Sid      = "DecryptSecrets"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = var.kms_key_arn
      },
      {
        Sid      = "ReadWriteOwnObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${var.s3_bucket_arn}/${local.s3_prefix}/*"
      },
      {
        Sid       = "ListOwnPrefix"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = var.s3_bucket_arn
        Condition = { StringLike = { "s3:prefix" = ["${local.s3_prefix}/*"] } }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_access" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app_access.arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.managed_policy_arns

  role       = aws_iam_role.app.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.full_name}-ec2-profile"
  role = aws_iam_role.app.name
}
