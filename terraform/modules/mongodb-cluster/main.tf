# MongoDB Cluster Module
# Deploys MongoDB clusters via Ops Manager and Kubernetes

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

locals {
  namespace = "mongodb-${var.project_name}"
  members   = var.cluster_type == "Standalone" ? 1 : var.members
}

# Step 1: Create Ops Manager Project
resource "null_resource" "create_project" {
  triggers = {
    project_name  = var.project_name
    version       = var.cluster_version
    script_hash   = filemd5("${var.scripts_path}/create-project.sh")
    depends_on_id = var.depends_on_resource_id
  }

  provisioner "local-exec" {
    command     = "${var.scripts_path}/create-project.sh ${var.project_name}"
    working_dir = var.project_path

    environment = {
      OPS_MANAGER_URL             = var.ops_manager_url
      OPS_MANAGER_ORG_ID          = var.ops_manager_org_id
      OPS_MANAGER_API_PUBLIC_KEY  = var.ops_manager_api_public_key
      OPS_MANAGER_API_PRIVATE_KEY = var.ops_manager_api_private_key
    }
  }
}

# Step 2: Generate Kustomize Overlay
resource "null_resource" "generate_overlay" {
  depends_on = [null_resource.create_project]

  triggers = {
    project_name  = var.project_name
    cluster_type  = var.cluster_type
    members       = local.members
    version       = var.cluster_version
    script_hash   = filemd5("${var.scripts_path}/new-overlay.sh")
    project_id    = null_resource.create_project.id
  }

  provisioner "local-exec" {
    command     = "${var.scripts_path}/new-overlay.sh ${var.project_name} --type ${var.cluster_type} --members ${local.members} --cpu-limit ${var.cpu_limit} --memory-limit ${var.memory_limit}"
    working_dir = var.project_path

    environment = {
      OPS_MANAGER_URL             = var.ops_manager_url
      OPS_MANAGER_ORG_ID          = var.ops_manager_org_id
      OPS_MANAGER_API_PUBLIC_KEY  = var.ops_manager_api_public_key
      OPS_MANAGER_API_PRIVATE_KEY = var.ops_manager_api_private_key
    }
  }

  # Clean up overlay on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers.project_name != "" ? "${path.module}/../../../k8s/overlays/${self.triggers.project_name}" : "/dev/null"} 2>/dev/null || true"
  }
}

# Step 3: Deploy to Kubernetes
resource "null_resource" "deploy_cluster" {
  depends_on = [null_resource.generate_overlay]

  triggers = {
    project_name = var.project_name
    version      = var.cluster_version
    overlay_id   = null_resource.generate_overlay.id
  }

  provisioner "local-exec" {
    command     = "kubectl apply -k k8s/overlays/${var.project_name}"
    working_dir = var.project_path
  }

  # Delete Kubernetes resources on destroy
  provisioner "local-exec" {
    when        = destroy
    command     = "kubectl delete -k k8s/overlays/${self.triggers.project_name} --ignore-not-found=true 2>/dev/null || true"
    working_dir = path.module
    on_failure  = continue
  }
}

# Step 4: Wait for MongoDB to be ready
resource "null_resource" "wait_for_ready" {
  depends_on = [null_resource.deploy_cluster]

  triggers = {
    deploy_id = null_resource.deploy_cluster.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for MongoDB ${var.project_name} to be ready..."
      for i in $(seq 1 60); do
        PHASE=$(kubectl get mongodb ${var.project_name} -n ${local.namespace} -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$PHASE" = "Running" ]; then
          echo "MongoDB ${var.project_name} is ready!"
          exit 0
        fi
        echo "  Phase: $PHASE (attempt $i/60)"
        sleep 10
      done
      echo "WARNING: Timeout waiting for MongoDB to be ready"
      exit 0
    EOT
  }
}
