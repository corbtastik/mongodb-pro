#!/bin/bash
# Start everything back up
# - Starts the Ops Manager VM
# - Waits for Ops Manager to be ready
# - Scales up K8s MongoDB workloads
set -e

VM_NAME="opsmanager"
NAMESPACE="mongodb"

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

# Scale up K8s MongoDB workloads
echo ""
echo "=== Scaling up K8s MongoDB deployments ==="
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    # Scale up standalone (1 replica)
    if kubectl get statefulset demo-standalone -n "$NAMESPACE" &>/dev/null; then
        echo "Scaling up demo-standalone..."
        kubectl scale statefulset demo-standalone --replicas=1 -n "$NAMESPACE"
    fi

    # Scale up replica set (3 replicas)
    if kubectl get statefulset demo-rs -n "$NAMESPACE" &>/dev/null; then
        echo "Scaling up demo-rs..."
        kubectl scale statefulset demo-rs --replicas=3 -n "$NAMESPACE"
    fi

    echo ""
    echo "Waiting for MongoDB pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=mongodb -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

    echo ""
    kubectl get mongodb,pods -n "$NAMESPACE"
else
    echo "Namespace '$NAMESPACE' not found. Skipping K8s."
fi

echo ""
echo "=== Environment started ==="
echo ""
echo "Ops Manager: http://opsmanager.orb.local:8080"
echo ""
echo "MongoDB connections:"
echo "  Standalone: mongosh 'mongodb://demouser:MongoDBPass123!@192.168.139.2:31261/admin'"
echo "  ReplicaSet: mongosh 'mongodb://demouser:MongoDBPass123!@192.168.139.2:30191/admin?replicaSet=demo-rs'"
