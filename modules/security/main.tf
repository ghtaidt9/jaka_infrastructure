# KMS key for every application secret

resource "aws_kms_key" "secrets" {
  description             = "${var.name_prefix} key for Secrets Manager secrets"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_in_days
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# IAM user allowed to start SSM sessions on instances tagged SSMAccess=true.
# No access key is created here, so no secret lands in state. Create one with:
#   aws iam create-access-key --user-name <name-prefix>-ssm-caller

resource "aws_iam_user" "ssm_caller" {
  count = var.create_ssm_caller_user ? 1 : 0

  name = "${var.name_prefix}-ssm-caller"
  path = "/"
}

resource "aws_iam_policy" "ssm_caller" {
  count = var.create_ssm_caller_user ? 1 : 0

  name        = "${var.name_prefix}-ssm-caller-policy"
  description = "Allow StartSession only for instances tagged SSMAccess=true"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowSSMStartOnTaggedInstances",
        Effect = "Allow",
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:DescribeInstanceInformation"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/SSMAccess" = "true"
          }
        }
      },
      {
        Sid    = "AllowSSMMessagesChannels",
        Effect = "Allow",
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      },
      {
        Sid    = "DescribeNeededResources",
        Effect = "Allow",
        Action = [
          "ssm:DescribeInstanceInformation",
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "ssm_caller" {
  count = var.create_ssm_caller_user ? 1 : 0

  user       = aws_iam_user.ssm_caller[0].name
  policy_arn = aws_iam_policy.ssm_caller[0].arn
}
