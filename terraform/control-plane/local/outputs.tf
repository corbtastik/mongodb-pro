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
# API Credentials (for data-plane)
# =============================================================================
# These outputs are used by the data-plane module to deploy clusters.

output "org_id" {
  description = "Ops Manager Organization ID"
  value       = var.ops_manager_org_id
}

output "api_public_key" {
  description = "Ops Manager API Public Key"
  value       = var.ops_manager_api_public_key
}

output "api_private_key" {
  description = "Ops Manager API Private Key"
  value       = var.ops_manager_api_private_key
  sensitive   = true
}

# =============================================================================
# Status
# =============================================================================

output "operator_ready" {
  description = "Whether the K8s operator is deployed and ready"
  value       = local.credentials_ready
}

output "next_steps" {
  description = "Instructions for next steps"
  value = local.credentials_ready ? join("\n", [
    "",
    "============================================================",
    "Control Plane Ready!",
    "============================================================",
    "",
    "The Ops Manager and K8s Operator are deployed.",
    "",
    "Next: Deploy MongoDB clusters using the data-plane module:",
    "  cd ../../../data-plane/local",
    "  cp terraform.tfvars.example terraform.tfvars",
    "  # Edit terraform.tfvars with your cluster configuration",
    "  terraform init && terraform apply",
    "",
    "============================================================",
    ""
  ]) : join("\n", [
    "",
    "============================================================",
    "NEXT STEPS - Create API Key in Ops Manager UI",
    "============================================================",
    "",
    "1. Open: ${module.ops_manager.ops_manager_url}",
    "2. Create admin user (first user becomes admin)",
    "3. Complete the setup wizard",
    "4. Go to: Organization > Access Manager > API Keys",
    "5. Create API Key:",
    "   - Description: terraform",
    "   - Permissions: Organization Owner",
    "6. Add to Access List: 192.168.215.0/24",
    "7. Update terraform.tfvars with credentials",
    "8. Run: terraform apply",
    "",
    "============================================================",
    ""
  ])
}
