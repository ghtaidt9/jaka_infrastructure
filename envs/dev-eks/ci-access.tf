# This role is created by envs/shared - read it with a data source, don't recreate it
data "aws_iam_role" "gha_deploy" {
  name = "jaka-mod-gha-deploy-dev"
}

# 1) Let the role into the cluster
resource "aws_eks_access_entry" "gha_deploy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.gha_deploy.arn
  type          = "STANDARD"
}

# 2) Once inside, what it may do: Edit, only in namespace "dev"
resource "aws_eks_access_policy_association" "gha_deploy_edit" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.gha_deploy.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["dev"]
  }

  depends_on = [aws_eks_access_entry.gha_deploy]
}
