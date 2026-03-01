#!/bin/bash
# Destroy everything - ALL DATA WILL BE LOST
# - Deletes K8s MongoDB deployments and PVCs
# - Deletes the Ops Manager VM
set -e

VM_NAME="opsmanager"
NAMESPACE="mongodb"

echo "=== MongoDB Pro Environment Teardown ==="
echo ""
echo "WARNING: This will PERMANENTLY DELETE:"
echo "  - All K8s MongoDB deployments and data (PVCs)"
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

# Delete K8s resources
echo "=== Deleting K8s MongoDB resources ==="
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    # Delete MongoDB resources (this triggers cleanup in Ops Manager)
    kubectl delete mongodb --all -n "$NAMESPACE" 2>/dev/null || true

    # Delete MongoDBUsers
    kubectl delete mongodbuser --all -n "$NAMESPACE" 2>/dev/null || true

    # Wait for pods to terminate
    echo "Waiting for pods to terminate..."
    sleep 10

    # Delete PVCs (this deletes the data!)
    echo "Deleting PVCs..."
    kubectl delete pvc --all -n "$NAMESPACE" 2>/dev/null || true

    # Uninstall the operator
    echo "Uninstalling MongoDB Enterprise Operator..."
    helm uninstall enterprise-operator -n "$NAMESPACE" 2>/dev/null || true

    # Delete secrets and configmaps
    kubectl delete secret --all -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete configmap --all -n "$NAMESPACE" 2>/dev/null || true

    # Delete namespace
    echo "Deleting namespace..."
    kubectl delete namespace "$NAMESPACE" 2>/dev/null || true

    echo "K8s resources deleted."
else
    echo "Namespace '$NAMESPACE' not found. Skipping K8s cleanup."
fi

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
