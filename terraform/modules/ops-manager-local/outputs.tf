output "ops_manager_url" {
  description = "Ops Manager URL"
  value       = var.enable_tls ? "https://opsmanager.orb.local:8443" : "http://opsmanager.orb.local:8080"
}

output "tls_enabled" {
  description = "Whether TLS is enabled"
  value       = var.enable_tls
}

output "vm_resource_id" {
  description = "VM resource ID for dependency chaining"
  value       = null_resource.create_vm.id
}

output "ops_manager_resource_id" {
  description = "Ops Manager resource ID for dependency chaining"
  value       = null_resource.install_ops_manager.id
}

output "tls_resource_id" {
  description = "TLS resource ID for dependency chaining"
  value       = var.enable_tls ? null_resource.configure_tls[0].id : null
}
