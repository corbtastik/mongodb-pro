#!/bin/bash
# Part 2: Deploy MongoDB
# Sets up K8s operator and deploys a standalone MongoDB instance
# Run this after completing Ops Manager UI setup and updating .env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

echo "=== Part 2: Deploy MongoDB ==="
echo ""

# Check .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found"
    echo "Complete Part 1 and configure .env before running Part 2"
    exit 1
fi

# Step 1: Setup K8s Operator
echo ">>> Step 1/4: Setting up K8s Operator..."
"$SCRIPT_DIR/04-setup-k8s-operator.sh"

# Step 2: Create project
echo ""
echo ">>> Step 2/4: Creating Ops Manager project..."
"$SCRIPT_DIR/create-project.sh" demo-01

# Step 3: Generate overlay and deploy
echo ""
echo ">>> Step 3/4: Deploying MongoDB standalone..."
"$SCRIPT_DIR/new-overlay.sh" demo-01
kubectl apply -k "$PROJECT_DIR/k8s/overlays/demo-01"

# Step 4: Wait for MongoDB to be ready
echo ""
echo ">>> Step 4/4: Waiting for MongoDB to be ready..."
echo "Watching deployment (Ctrl+C when Running)..."
kubectl get mongodb,pods -n mongodb-demo-01 -w &
WATCH_PID=$!

# Wait for Running phase
for i in {1..60}; do
    PHASE=$(kubectl get mongodb demo-01 -n mongodb-demo-01 -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [[ "$PHASE" == "Running" ]]; then
        kill $WATCH_PID 2>/dev/null || true
        break
    fi
    sleep 5
done

echo ""
echo "=== Part 2 Complete ==="
echo ""
kubectl get mongodb,pods -n mongodb-demo-01
echo ""
echo "Load sample data:"
echo "  ./scripts/load-sample-data.sh demo-01"
echo "  ./scripts/query-sample-data.sh demo-01"
echo ""
echo "Connect:"
echo "  mongosh 'mongodb://dbAdmin:MongoDBPass123%21@192.168.139.2:30100/admin'"
echo ""
