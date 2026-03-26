output "operator_resource_id" {
  description = "Operator resource ID for dependency chaining"
  value       = null_resource.setup_k8s_operator.id
}
