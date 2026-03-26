# =============================================================================
# Local Environment - MongoDB Enterprise on OrbStack (macOS)
# =============================================================================

locals {
  # Paths relative to this terraform directory
  project_path = abspath("${path.module}/../../..")
  scripts_path = "${local.project_path}/scripts"

  # Ops Manager URL based on TLS setting
  ops_manager_url = var.enable_tls ? "https://opsmanager.orb.local:8443" : "http://opsmanager.orb.local:8080"
}

# =============================================================================
# Module 1: Ops Manager Infrastructure
# =============================================================================
# This module creates the VM, installs AppDB, Ops Manager, and configures TLS.
# After this completes, you must manually:
#   1. Open the Ops Manager UI
#   2. Create an admin user and organization
#   3. Create an API key
#   4. Update terraform.tfvars with the credentials
#   5. Run terraform apply again to continue with K8s operator and cluster

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
# Requires Ops Manager credentials to be configured.

module "k8s_operator" {
  source = "../../modules/k8s-operator"

  # Only deploy if we have credentials configured
  count = var.ops_manager_org_id != "" ? 1 : 0

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
# Module 3: MongoDB Cluster
# =============================================================================
# Deploys a MongoDB cluster (Standalone or ReplicaSet).

module "mongodb_cluster" {
  source = "../../modules/mongodb-cluster"

  # Only deploy if enabled and operator is deployed
  count = var.deploy_cluster && var.ops_manager_org_id != "" ? 1 : 0

  project_name                = var.cluster_name
  scripts_path                = local.scripts_path
  project_path                = local.project_path
  ops_manager_url             = local.ops_manager_url
  ops_manager_org_id          = var.ops_manager_org_id
  ops_manager_api_public_key  = var.ops_manager_api_public_key
  ops_manager_api_private_key = var.ops_manager_api_private_key
  cluster_type                = var.cluster_type
  members                     = var.cluster_members
  cpu_limit                   = var.cluster_cpu_limit
  memory_limit                = var.cluster_memory_limit
  cluster_version             = var.cluster_version

  depends_on_resource_id = module.k8s_operator[0].operator_resource_id
}
