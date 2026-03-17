#!/bin/bash
# Stop everything, preserve state
# - Scales down K8s MongoDB workloads (data preserved in PVCs)
# - Stops the Ops Manager VM
set -e

VM_NAME="opsmanager"

echo "=== Stopping MongoDB Pro Environment ==="
echo ""

# Scale down K8s MongoDB workloads across all mongodb namespaces
echo "=== Scaling down K8s MongoDB deployments ==="

FOUND_DEPLOYMENTS=false

# Find all mongodb namespaces and scale down statefulsets
for ns in $(kubectl get namespaces -o name 2>/dev/null | grep "^namespace/mongodb" | cut -d/ -f2); do
    # Get all MongoDB StatefulSets and scale to 0 (excluding operator)
    for sts in $(kubectl get statefulset -n "$ns" -o name 2>/dev/null | grep -v operator); do
        FOUND_DEPLOYMENTS=true
        echo "Scaling down $sts in $ns..."
        kubectl scale "$sts" --replicas=0 -n "$ns"
    done
done

if [ "$FOUND_DEPLOYMENTS" = true ]; then
    echo "Waiting for pods to terminate..."
    for ns in $(kubectl get namespaces -o name 2>/dev/null | grep "^namespace/mongodb" | cut -d/ -f2); do
        kubectl wait --for=delete pod -l app.kubernetes.io/component=mongodb -n "$ns" --timeout=60s 2>/dev/null || true
    done
    echo "K8s MongoDB pods stopped. PVCs preserved."
else
    echo "No MongoDB deployments found."
fi

echo ""

# Stop Ops Manager VM (preserves all data)
if orb list 2>/dev/null | grep -q "^${VM_NAME} .*running"; then
    echo "=== Stopping VM: ${VM_NAME} ==="
    orb stop "$VM_NAME"
    echo "VM stopped."
else
    echo "VM '$VM_NAME' is not running."
fi

echo ""
echo "=== Environment stopped ==="
echo ""
echo "All data is preserved:"
echo "  - VM disk: MongoDB AppDB + Ops Manager data"
echo "  - K8s PVCs: MongoDB cluster data"
echo ""
echo "Run ./scripts/start-all.sh to restart."
