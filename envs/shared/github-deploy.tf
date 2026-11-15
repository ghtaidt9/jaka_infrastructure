# Role for the deploy job - assumable only from the "dev" environment
resource "aws_iam_role" "gha_deploy_dev" {
  name = "${local.project}-gha-deploy-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleeWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.app_repo}:environment:dev"
        }
      }
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "gha_deploy_dev" {
  name = "eks-deploy"
  role = aws_iam_role.gha_deploy_dev.id

  policy = jsonencode({
    Version : "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/jaka-mode-dev-eks"
      },
      {
        Sid      = "ReadEcrTags"
        Effect   = "Allow"
        Action   = ["ecr:DescribeImages"]
        Resource = values(module.ecr.repository_arns)
      },
    ]
  })
}
