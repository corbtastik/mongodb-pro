# Ops Manager Local Module
# Installs Ops Manager infrastructure on OrbStack (macOS)

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Step 1: Create OrbStack VM
resource "null_resource" "create_vm" {
  triggers = {
    version     = var.vm_version
    script_hash = filemd5("${var.scripts_path}/01-create-opsmanager-vm.sh")
  }

  provisioner "local-exec" {
    command     = "${var.scripts_path}/01-create-opsmanager-vm.sh"
    working_dir = dirname(var.scripts_path)
  }

  # Destroy: Delete the OrbStack VM
  provisioner "local-exec" {
    when       = destroy
    command    = "orb delete opsmanager -f 2>/dev/null || true"
    on_failure = continue
  }
}

# Step 2: Install MongoDB AppDB (3-node replica set)
resource "null_resource" "install_appdb" {
  depends_on = [null_resource.create_vm]

  triggers = {
    version     = var.appdb_version
    script_hash = filemd5("${var.scripts_path}/02-install-appdb.sh")
    vm_id       = null_resource.create_vm.id
  }

  provisioner "local-exec" {
    command     = "${var.scripts_path}/02-install-appdb.sh"
    working_dir = dirname(var.scripts_path)
  }
}

# Step 3: Install Ops Manager
resource "null_resource" "install_ops_manager" {
  depends_on = [null_resource.install_appdb]

  triggers = {
    version     = var.ops_manager_version
    script_hash = filemd5("${var.scripts_path}/03-install-opsmanager.sh")
    appdb_id    = null_resource.install_appdb.id
  }

  provisioner "local-exec" {
    command     = "${var.scripts_path}/03-install-opsmanager.sh"
    working_dir = dirname(var.scripts_path)
  }
}

# Step 4: Configure TLS (optional)
resource "null_resource" "configure_tls" {
  count      = var.enable_tls ? 1 : 0
  depends_on = [null_resource.install_ops_manager]

  triggers = {
    version         = var.tls_version
    script_hash     = filemd5("${var.scripts_path}/03a-configure-tls.sh")
    ops_manager_id  = null_resource.install_ops_manager.id
    scripts_path    = var.scripts_path
  }

  provisioner "local-exec" {
    command     = "${var.scripts_path}/03a-configure-tls.sh"
    working_dir = dirname(var.scripts_path)
  }

  # Destroy: Clean up generated certificates
  provisioner "local-exec" {
    when       = destroy
    command    = "rm -rf ${self.triggers.scripts_path}/certs 2>/dev/null || true"
    on_failure = continue
  }
}
