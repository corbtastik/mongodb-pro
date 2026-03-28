# =============================================================================
# Control Plane - MongoDB Ops Manager on OrbStack (macOS)
# =============================================================================
# Deploys the MongoDB Enterprise control plane:
# - OrbStack VM with Ops Manager
# - MongoDB AppDB (3-node replica set)
# - TLS certificates (optional)
# - MongoDB Enterprise Kubernetes Operator

locals {
  # Paths relative to this terraform directory
  project_path = abspath("${path.module}/../../..")
  scripts_path = "${local.project_path}/scripts"

  # Ops Manager URL based on TLS setting
  ops_manager_url = var.enable_tls ? "https://opsmanager.orb.local:8443" : "http://opsmanager.orb.local:8080"

  # Check if we have credentials to deploy the operator
  credentials_ready = var.ops_manager_org_id != "" && var.ops_manager_api_public_key != ""
}

# =============================================================================
# Ops Manager Infrastructure
# =============================================================================
# Creates the VM, installs AppDB, Ops Manager, and configures TLS.

module "ops_manager" {
  source = "../../modules/ops-manager-local"

  scripts_path        = local.scripts_path
  enable_tls          = var.enable_tls
  vm_version          = var.vm_version
  appdb_version       = var.appdb_version
  ops_manager_version = var.ops_manager_version
  tls_version         = var.tls_version
}

# =============================================================================
# Kubernetes Operator
# =============================================================================
# Deploys the MongoDB Enterprise Kubernetes Operator.
# Requires Ops Manager API credentials.

module "k8s_operator" {
  source = "../../modules/k8s-operator"

  # Only deploy if we have valid API credentials
  count = local.credentials_ready ? 1 : 0

  scripts_path                = local.scripts_path
  project_path                = local.project_path
  ops_manager_url             = local.ops_manager_url
  ops_manager_org_id          = var.ops_manager_org_id
  ops_manager_api_public_key  = var.ops_manager_api_public_key
  ops_manager_api_private_key = var.ops_manager_api_private_key
  operator_version            = var.operator_version

  depends_on_resource_id = var.enable_tls ? module.ops_manager.tls_resource_id : module.ops_manager.ops_manager_resource_id
}
