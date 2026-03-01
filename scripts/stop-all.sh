#!/bin/bash
# Stop everything, preserve state
# - Scales down K8s MongoDB workloads (data preserved in PVCs)
# - Stops the Ops Manager VM
set -e

VM_NAME="opsmanager"
NAMESPACE="mongodb"

echo "=== Stopping MongoDB Pro Environment ==="
echo ""

# Scale down K8s MongoDB workloads
echo "=== Scaling down K8s MongoDB deployments ==="
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    # Get all MongoDB StatefulSets and scale to 0
    for sts in $(kubectl get statefulset -n "$NAMESPACE" -o name 2>/dev/null | grep -v operator); do
        echo "Scaling down $sts..."
        kubectl scale "$sts" --replicas=0 -n "$NAMESPACE"
    done

    echo "Waiting for pods to terminate..."
    kubectl wait --for=delete pod -l app.kubernetes.io/component=mongodb -n "$NAMESPACE" --timeout=60s 2>/dev/null || true

    echo "K8s MongoDB pods stopped. PVCs preserved."
else
    echo "Namespace '$NAMESPACE' not found. Skipping K8s."
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
