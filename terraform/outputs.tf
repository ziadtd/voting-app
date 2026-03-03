output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
}
