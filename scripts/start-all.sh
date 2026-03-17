#!/bin/bash
# Start everything back up
# - Starts the Ops Manager VM
# - Waits for Ops Manager to be ready
# - Scales up K8s MongoDB workloads
set -e

VM_NAME="opsmanager"

echo "=== Starting MongoDB Pro Environment ==="
echo ""

# Start Ops Manager VM
if orb list 2>/dev/null | grep -q "^${VM_NAME} "; then
    if orb list 2>/dev/null | grep -q "^${VM_NAME} .*running"; then
        echo "VM '$VM_NAME' is already running."
    else
        echo "=== Starting VM: ${VM_NAME} ==="
        orb start "$VM_NAME"
        echo "Waiting for VM to be ready..."
        sleep 5
    fi
else
    echo "ERROR: VM '$VM_NAME' does not exist. Run ./scripts/01-create-opsmanager-vm.sh first."
    exit 1
fi

# Wait for MongoDB AppDB to be ready
echo ""
echo "=== Waiting for MongoDB AppDB ==="
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if orb -m "$VM_NAME" systemctl is-active --quiet mongod-rs1 2>/dev/null; then
        echo "MongoDB AppDB is running."
        break
    fi
    echo "  Waiting for AppDB... (${WAITED}s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "WARNING: MongoDB AppDB may not be running."
    echo "Check with: orb -m $VM_NAME -u root systemctl status mongod-rs1"
fi

# Wait for Ops Manager to be ready
echo ""
echo "=== Waiting for Ops Manager ==="
MAX_WAIT=180
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://opsmanager.orb.local:8080 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "303" ]; then
        echo "Ops Manager is ready! (HTTP $HTTP_CODE)"
        break
    fi
    echo "  Waiting for Ops Manager... (${WAITED}s)"
    sleep 10
    WAITED=$((WAITED + 10))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "WARNING: Ops Manager may still be starting."
    echo "Check with: orb -m $VM_NAME -u root systemctl status mongodb-mms"
fi

# Scale up K8s MongoDB workloads across all mongodb namespaces
echo ""
echo "=== Scaling up K8s MongoDB deployments ==="

FOUND_DEPLOYMENTS=false

# Find all mongodb namespaces
for ns in $(kubectl get namespaces -o name 2>/dev/null | grep "^namespace/mongodb" | cut -d/ -f2); do
    # Get all MongoDB resources in this namespace
    for mongodb in $(kubectl get mongodb -n "$ns" -o name 2>/dev/null); do
        FOUND_DEPLOYMENTS=true
        name=$(echo "$mongodb" | cut -d/ -f2)

        # Get the desired member count from the MongoDB spec (default to 1 for standalone)
        members=$(kubectl get mongodb "$name" -n "$ns" -o jsonpath='{.spec.members}' 2>/dev/null || echo "1")

        # Scale the corresponding statefulset
        if kubectl get statefulset "$name" -n "$ns" &>/dev/null; then
            echo "Scaling up $name in $ns to $members replica(s)..."
            kubectl scale statefulset "$name" --replicas="$members" -n "$ns"
        fi
    done
done

if [ "$FOUND_DEPLOYMENTS" = true ]; then
    echo ""
    echo "Waiting for MongoDB pods to be ready..."
    for ns in $(kubectl get namespaces -o name 2>/dev/null | grep "^namespace/mongodb" | cut -d/ -f2); do
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=mongodb -n "$ns" --timeout=120s 2>/dev/null || true
    done

    echo ""
    echo "MongoDB deployments:"
    for ns in $(kubectl get namespaces -o name 2>/dev/null | grep "^namespace/mongodb" | cut -d/ -f2); do
        if kubectl get mongodb -n "$ns" &>/dev/null 2>&1; then
            kubectl get mongodb,pods -n "$ns" 2>/dev/null || true
        fi
    done
else
    echo "No MongoDB deployments found."
fi

echo ""
echo "=== Environment started ==="
echo ""
echo "Ops Manager: http://opsmanager.orb.local:8080"
echo ""
echo "To get a connection string for a deployment, run:"
echo "  ./scripts/get-connection-string.sh <project-name>"
