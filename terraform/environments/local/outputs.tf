# =============================================================================
# Ops Manager Outputs
# =============================================================================

output "ops_manager_url" {
  description = "Ops Manager URL"
  value       = module.ops_manager.ops_manager_url
}

output "tls_enabled" {
  description = "Whether TLS is enabled for Ops Manager"
  value       = module.ops_manager.tls_enabled
}

# =============================================================================
# MongoDB Cluster Outputs
# =============================================================================

output "cluster_deployed" {
  description = "Whether a MongoDB cluster was deployed"
  value       = var.deploy_cluster && var.ops_manager_org_id != ""
}

output "cluster_namespace" {
  description = "Kubernetes namespace for the MongoDB cluster"
  value       = var.deploy_cluster && var.ops_manager_org_id != "" ? module.mongodb_cluster[0].namespace : null
}

output "cluster_name" {
  description = "MongoDB cluster name"
  value       = var.deploy_cluster && var.ops_manager_org_id != "" ? module.mongodb_cluster[0].cluster_name : null
}

output "cluster_type" {
  description = "MongoDB cluster type"
  value       = var.deploy_cluster && var.ops_manager_org_id != "" ? module.mongodb_cluster[0].cluster_type : null
}

output "connection_string_template" {
  description = "MongoDB connection string template"
  value       = var.deploy_cluster && var.ops_manager_org_id != "" ? module.mongodb_cluster[0].connection_string_template : null
}

# =============================================================================
# Next Steps
# =============================================================================

output "next_steps" {
  description = "Instructions for next steps"
  value       = var.ops_manager_org_id == "" ? <<-EOT

    ============================================================
    NEXT STEPS - Ops Manager UI Configuration Required
    ============================================================

    1. Open: ${module.ops_manager.ops_manager_url}
    2. Create admin user and organization
    3. Create API key:
       - Organization → Access Manager → API Keys
       - Permissions: Organization Owner
       - Access List: 192.168.139.0/24
    4. Update terraform.tfvars:
       ops_manager_org_id          = "<org-id>"
       ops_manager_api_public_key  = "<public-key>"
       ops_manager_api_private_key = "<private-key>"
    5. Run: terraform apply

    ============================================================
  EOT
  : "Deployment complete! Use 'kubectl get mongodb -A' to check status."
}
