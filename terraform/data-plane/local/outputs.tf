# =============================================================================
# Control Plane Info (from remote state)
# =============================================================================

output "ops_manager_url" {
  description = "Ops Manager URL (from control-plane)"
  value       = local.ops_manager_url
}

output "ops_manager_org_id" {
  description = "Ops Manager Organization ID (from control-plane)"
  value       = local.ops_manager_org_id
}

# =============================================================================
# MongoDB Cluster Outputs
# =============================================================================

output "clusters" {
  description = "Deployed MongoDB clusters"
  value = {
    for name, cluster in module.mongodb_cluster : name => {
      namespace         = cluster.namespace
      cluster_name      = cluster.cluster_name
      cluster_type      = cluster.cluster_type
      connection_string = cluster.connection_string_template
    }
  }
}

output "cluster_count" {
  description = "Number of clusters deployed"
  value       = length(var.clusters)
}

output "cluster_names" {
  description = "List of deployed cluster names"
  value       = keys(var.clusters)
}
