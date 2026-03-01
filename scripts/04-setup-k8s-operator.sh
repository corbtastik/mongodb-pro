#!/bin/bash
# Step 4: Set up MongoDB Enterprise Kubernetes Operator
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"
ENV_FILE="$PROJECT_DIR/.env"

echo "=== Setting up MongoDB Enterprise Kubernetes Operator ==="
echo ""

# Check kubectl access
if ! kubectl cluster-info &>/dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster."
    echo "Make sure OrbStack Kubernetes is enabled."
    exit 1
fi

# Check for .env file
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    echo "Create it with your Ops Manager credentials:"
    echo "  OPS_MANAGER_URL=http://opsmanager.orb.local:8080"
    echo "  OPS_MANAGER_ORG_ID=<org-id>"
    echo "  OPS_MANAGER_API_PUBLIC_KEY=<public-key>"
    echo "  OPS_MANAGER_API_PRIVATE_KEY=<private-key>"
    exit 1
fi

# Load environment
source "$ENV_FILE"

# Check for Helm
if ! command -v helm &>/dev/null; then
    echo "Installing Helm..."
    brew install helm
fi

# Add MongoDB Helm repo
echo "=== Adding MongoDB Helm repository ==="
helm repo add mongodb https://mongodb.github.io/helm-charts 2>/dev/null || true
helm repo update

# Create namespace
echo ""
echo "=== Creating mongodb namespace ==="
kubectl apply -f "$K8S_DIR/namespace.yaml"

# Create ConfigMaps with Ops Manager connection details
echo ""
echo "=== Creating Ops Manager ConfigMaps ==="

# ConfigMap for lab-01 (standalone deployments)
cat > "$K8S_DIR/ops-manager-config.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ops-manager-connection
  namespace: mongodb
data:
  baseUrl: ${OPS_MANAGER_URL}
  orgId: ${OPS_MANAGER_ORG_ID}
  projectName: lab-01
EOF
kubectl apply -f "$K8S_DIR/ops-manager-config.yaml"

# ConfigMap for lab-02 (replica set deployments)
cat > "$K8S_DIR/ops-manager-config-lab02.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ops-manager-connection-lab02
  namespace: mongodb
data:
  baseUrl: ${OPS_MANAGER_URL}
  orgId: ${OPS_MANAGER_ORG_ID}
  projectName: lab-02
EOF
kubectl apply -f "$K8S_DIR/ops-manager-config-lab02.yaml"

# Create Secret with API credentials
echo ""
echo "=== Creating Ops Manager credentials Secret ==="
cat > "$K8S_DIR/ops-manager-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ops-manager-credentials
  namespace: mongodb
type: Opaque
stringData:
  publicKey: ${OPS_MANAGER_API_PUBLIC_KEY}
  privateKey: "${OPS_MANAGER_API_PRIVATE_KEY}"
EOF
kubectl apply -f "$K8S_DIR/ops-manager-secret.yaml"

# Install the operator
echo ""
echo "=== Installing MongoDB Enterprise Operator ==="
if helm status enterprise-operator -n mongodb &>/dev/null; then
    echo "Operator already installed. Upgrading..."
    helm upgrade enterprise-operator mongodb/enterprise-operator \
        --namespace mongodb \
        --set operator.watchNamespace=mongodb
else
    helm install enterprise-operator mongodb/enterprise-operator \
        --namespace mongodb \
        --set operator.watchNamespace=mongodb
fi

# Wait for operator to be ready
echo ""
echo "=== Waiting for operator to be ready ==="
kubectl rollout status deployment/mongodb-enterprise-operator -n mongodb --timeout=120s

echo ""
echo "=== Operator setup complete ==="
kubectl get pods -n mongodb

echo ""
echo "=== Next steps ==="
echo ""
echo "Deploy MongoDB clusters:"
echo "  kubectl apply -f k8s/mongodb-standalone.yaml   # Standalone in lab-01"
echo "  kubectl apply -f k8s/mongodb-replicaset.yaml   # ReplicaSet in lab-02"
echo ""
echo "Create users:"
echo "  kubectl apply -f k8s/mongodb-user-secret.yaml"
echo "  kubectl apply -f k8s/mongodb-user.yaml         # User for standalone"
echo "  kubectl apply -f k8s/mongodb-user-rs.yaml      # User for replica set"
