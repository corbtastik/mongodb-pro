# =============================================================================
# Local Environment - MongoDB Enterprise on OrbStack (macOS)
# =============================================================================

locals {
  # Paths relative to this terraform directory
  project_path = abspath("${path.module}/../../..")
  scripts_path = "${local.project_path}/scripts"

  # Ops Manager URL based on TLS setting
  ops_manager_url = var.enable_tls ? "https://opsmanager.orb.local:8443" : "http://opsmanager.orb.local:8080"

  # Check if we have credentials to proceed with operator/cluster deployment
  credentials_ready = var.ops_manager_org_id != "" && var.ops_manager_api_public_key != ""
}

# =============================================================================
# Module 1: Ops Manager Infrastructure
# =============================================================================
# This module creates the VM, installs AppDB, Ops Manager, and configures TLS.

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
# Module 2: Kubernetes Operator
# =============================================================================
# Deploys the MongoDB Enterprise Kubernetes Operator.

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

# =============================================================================
# Module 3: MongoDB Clusters
# =============================================================================
# Deploys MongoDB clusters (Standalone or ReplicaSet) using for_each.

module "mongodb_cluster" {
  source = "../../modules/mongodb-cluster"

  # Deploy each cluster defined in the clusters map (requires operator)
  for_each = local.credentials_ready ? var.clusters : {}

  project_name                = each.key
  scripts_path                = local.scripts_path
  project_path                = local.project_path
  ops_manager_url             = local.ops_manager_url
  ops_manager_org_id          = var.ops_manager_org_id
  ops_manager_api_public_key  = var.ops_manager_api_public_key
  ops_manager_api_private_key = var.ops_manager_api_private_key
  cluster_type                = each.value.type
  members                     = each.value.members
  cpu_limit                   = each.value.cpu_limit
  memory_limit                = each.value.memory_limit
  cluster_version             = each.value.version

  depends_on_resource_id = module.k8s_operator[0].operator_resource_id
}
