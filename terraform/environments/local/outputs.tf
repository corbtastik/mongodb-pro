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

# =============================================================================
# Next Steps
# =============================================================================

output "next_steps" {
  description = "Instructions for next steps"
  value = local.credentials_ready ? "Deployment complete! Use 'kubectl get mongodb -A' to check status." : join("\n", [
    "",
    "============================================================",
    "NEXT STEPS - Create API Key in Ops Manager UI",
    "============================================================",
    "",
    "1. Open: ${module.ops_manager.ops_manager_url}",
    "2. Go to: Organization > Access Manager > API Keys",
    "3. Create API Key:",
    "   - Description: terraform",
    "   - Permissions: Organization Owner",
    "4. Add to Access List: 192.168.215.0/24",
    "5. Copy Organization ID (from URL or Organization Settings)",
    "6. Update terraform.tfvars:",
    "   ops_manager_org_id          = \"<org-id>\"",
    "   ops_manager_api_public_key  = \"<public-key>\"",
    "   ops_manager_api_private_key = \"<private-key>\"",
    "7. Run: terraform apply",
    "",
    "============================================================",
    ""
  ])
}
