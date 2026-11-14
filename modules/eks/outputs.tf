output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint (what kubectl talks to)"
  value       = module.eks.cluster_endpoint
}

output "node_security_group_id" {
  description = "Security group of the worker nodes"
  value       = module.eks.node_security_group_id
}