# outputs.tf
output "cluster_name" {
  description = "Nombre del cluster Kind"
  value       = kind_cluster.default.name
}

output "kubeconfig_path" {
  description = "Ruta del archivo kubeconfig"
  value       = kind_cluster.default.kubeconfig_path
}

output "control_plane_ip" {
  description = "IP del nodo control-plane"
  value       = kind_cluster.default.node_image
}

output "worker_nodes" {
  description = "Número de nodos worker"
  value       = length([for node in kind_cluster.default.kind_config[0].node : node if node.role == "worker"])
}

output "ingress_ready" {
  description = "Estado de Ingress Controller"
  value       = length([for node in kind_cluster.default.kind_config[0].node : node if node.role == "control-plane" && can(regex("ingress-ready=true", node.kubeadm_config_patches[0]))])
}