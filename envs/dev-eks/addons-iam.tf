locals {
  eso_secret_arns = concat(
    values({ for k, db in module.postgres : k => db.app_secret_arn }),
    values({ for k, db in module.postgres : k => db.admin_secret_arn }),
    [module.redis.auth_secret_arn],
  )
}

# Loadbalancer controller iam

resource "aws_iam_policy" "lb_controller" {
  name   = "${local.name_prefix}-lb-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role" "lb_controller" {
  name               = "${local.name_prefix}-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_trust.json
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn
}


# External Secret Operator iam
data "aws_iam_policy_document" "eso" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = local.eso_secret_arns
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = [module.security.kms_key_arn] # cả 9 secret mã hóa bằng key này
  }
}

resource "aws_iam_role" "eso" {
  name               = "${local.name_prefix}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.pod_trust.json
}

resource "aws_iam_role_policy" "eso" {
  role   = aws_iam_role.eso.name
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn
}

