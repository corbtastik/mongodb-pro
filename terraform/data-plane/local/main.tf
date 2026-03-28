# =============================================================================
# Data Plane - MongoDB Clusters on OrbStack (macOS)
# =============================================================================
# Deploys MongoDB clusters managed by Ops Manager.
# Requires the control-plane to be deployed first.

locals {
  # Paths relative to this terraform directory
  project_path = abspath("${path.module}/../../..")
  scripts_path = "${local.project_path}/scripts"
}

# =============================================================================
# Control Plane State
# =============================================================================
# Read credentials and config from the control-plane state file.

data "terraform_remote_state" "control_plane" {
  backend = "local"

  config = {
    path = "${path.module}/../../control-plane/local/terraform.tfstate"
  }
}

locals {
  # Get values from control-plane outputs
  ops_manager_url         = data.terraform_remote_state.control_plane.outputs.ops_manager_url
  ops_manager_org_id      = data.terraform_remote_state.control_plane.outputs.org_id
  ops_manager_public_key  = data.terraform_remote_state.control_plane.outputs.api_public_key
  ops_manager_private_key = data.terraform_remote_state.control_plane.outputs.api_private_key
}

# =============================================================================
# MongoDB Clusters
# =============================================================================
# Deploys MongoDB clusters using for_each on the clusters map.

module "mongodb_cluster" {
  source = "../../modules/mongodb-cluster"

  for_each = var.clusters

  project_name                = each.key
  scripts_path                = local.scripts_path
  project_path                = local.project_path
  ops_manager_url             = local.ops_manager_url
  ops_manager_org_id          = local.ops_manager_org_id
  ops_manager_api_public_key  = local.ops_manager_public_key
  ops_manager_api_private_key = local.ops_manager_private_key
  cluster_type                = each.value.type
  members                     = each.value.members
  cpu_limit                   = each.value.cpu_limit
  memory_limit                = each.value.memory_limit
  cluster_version             = each.value.version

  depends_on_resource_id = "control-plane-deployed"
}
