#!/bin/bash
# Destroy everything - ALL DATA WILL BE LOST
# - Deletes ALL K8s MongoDB deployments and PVCs (all namespaces)
# - Deletes the Ops Manager VM
set -e

VM_NAME="opsmanager"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== MongoDB Pro Environment Teardown ==="
echo ""
echo "WARNING: This will PERMANENTLY DELETE:"
echo "  - All K8s MongoDB deployments and data (PVCs)"
echo "  - All mongodb-* namespaces"
echo "  - VM '$VM_NAME' and all its data"
echo "  - MongoDB AppDB data"
echo "  - Ops Manager configuration"
echo ""
read -p "Are you sure? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""

# Delete K8s resources across ALL mongodb namespaces
echo "=== Deleting K8s MongoDB resources (all namespaces) ==="

# Delete all MongoDB resources across all namespaces
echo "Deleting MongoDB resources..."
kubectl delete mongodb --all -A 2>/dev/null || true
kubectl delete mongodbuser --all -A 2>/dev/null || true

# Wait for pods to terminate
echo "Waiting for pods to terminate..."
sleep 10

# Uninstall the operator
echo "Uninstalling MongoDB Enterprise Operator..."
helm uninstall enterprise-operator -n mongodb 2>/dev/null || true

# Delete all mongodb-* namespaces
echo "Deleting mongodb namespaces..."
kubectl get namespaces -o name | grep "namespace/mongodb" | xargs -r kubectl delete 2>/dev/null || true

# Clean up local overlay directories (keep lab-01, lab-02)
echo "Cleaning up local overlay directories..."
rm -rf "$PROJECT_ROOT"/k8s/overlays/demo-* "$PROJECT_ROOT"/k8s/overlays/dev-* 2>/dev/null || true

echo "K8s resources deleted."

echo ""

# Delete the VM
if orb list 2>/dev/null | grep -q "^${VM_NAME} "; then
    echo "=== Deleting VM: ${VM_NAME} ==="
    orb delete -f "$VM_NAME"
    echo "VM deleted."
else
    echo "VM '$VM_NAME' does not exist."
fi

echo ""
echo "=== Teardown complete ==="
echo "All data has been destroyed."
echo ""
echo "To start fresh, run:"
echo "  ./scripts/01-create-opsmanager-vm.sh"
echo "  ./scripts/02-install-appdb.sh"
echo "  ./scripts/03-install-opsmanager.sh"
echo "  ./scripts/04-setup-k8s-operator.sh"
