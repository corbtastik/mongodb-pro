output "namespace" {
  description = "Kubernetes namespace for this MongoDB deployment"
  value       = local.namespace
}

output "cluster_name" {
  description = "MongoDB cluster name"
  value       = var.project_name
}

output "cluster_type" {
  description = "MongoDB cluster type"
  value       = var.cluster_type
}

output "members" {
  description = "Number of cluster members"
  value       = local.members
}

output "connection_string_template" {
  description = "MongoDB connection string template (replace <nodeport> with actual port)"
  value       = "mongodb://dbAdmin:MongoDBPass123%21@192.168.139.2:<nodeport>/admin"
}

output "cluster_resource_id" {
  description = "Cluster resource ID for dependency chaining"
  value       = null_resource.wait_for_ready.id
}
