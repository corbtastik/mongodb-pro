# Kubernetes Operator Module
# Deploys MongoDB Enterprise Kubernetes Operator

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Deploy K8s Operator
resource "null_resource" "setup_k8s_operator" {
  triggers = {
    version          = var.operator_version
    script_hash      = filemd5("${var.scripts_path}/04-setup-k8s-operator.sh")
    ops_manager_url  = var.ops_manager_url
    org_id           = var.ops_manager_org_id
    depends_on_id    = var.depends_on_resource_id
  }

  provisioner "local-exec" {
    command     = "${var.scripts_path}/04-setup-k8s-operator.sh"
    working_dir = var.project_path

    environment = {
      OPS_MANAGER_URL             = var.ops_manager_url
      OPS_MANAGER_ORG_ID          = var.ops_manager_org_id
      OPS_MANAGER_API_PUBLIC_KEY  = var.ops_manager_api_public_key
      OPS_MANAGER_API_PRIVATE_KEY = var.ops_manager_api_private_key
    }
  }
}
