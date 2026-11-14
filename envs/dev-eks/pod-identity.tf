data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "pod_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "pod_access" {
  for_each = local.services
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/jaka-mod/dev-eks/${each.key}/*"]
  }
}

resource "aws_iam_role" "pod" {
  for_each           = local.services
  name               = "${local.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.pod_trust.json
}


resource "aws_iam_role_policy" "pod" {
  for_each = local.services
  role     = aws_iam_role.pod[each.key].name
  policy   = data.aws_iam_policy_document.pod_access[each.key].json
}

resource "aws_eks_pod_identity_association" "pod" {
  for_each        = local.services
  cluster_name    = module.eks.cluster_name
  namespace       = "dev"
  service_account = each.key
  role_arn        = aws_iam_role.pod[each.key].arn
}