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
kubectl create namespace mongodb --dry-run=client -o yaml | kubectl apply -f -

# Create Ops Manager credentials Secret from .env
echo ""
echo "=== Creating Ops Manager credentials Secret ==="
kubectl create secret generic ops-manager-credentials \
    --namespace mongodb \
    --from-literal=publicKey="${OPS_MANAGER_API_PUBLIC_KEY}" \
    --from-literal=privateKey="${OPS_MANAGER_API_PRIVATE_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create user credentials Secret
echo ""
echo "=== Creating MongoDB user credentials Secret ==="
kubectl create secret generic mongodb-user-credentials \
    --namespace mongodb \
    --from-literal=dbUser-password="MongoDBPass123!" \
    --from-literal=dbAdmin-password="MongoDBPass123!" \
    --from-literal=sysAdmin-password="MongoDBPass123!" \
    --dry-run=client -o yaml | kubectl apply -f -

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
echo "Deploy MongoDB clusters using Kustomize:"
echo ""
echo "  # Standalone deployment (lab-01 project)"
echo "  kubectl apply -k k8s/overlays/lab-01"
echo ""
echo "  # ReplicaSet deployment (lab-02 project)"
echo "  kubectl apply -k k8s/overlays/lab-02"
echo ""
echo "  # Preview what will be deployed:"
echo "  kubectl kustomize k8s/overlays/lab-01"
echo ""
echo "Or use the legacy YAML files:"
echo "  kubectl apply -f k8s/mongodb-standalone.yaml"
echo "  kubectl apply -f k8s/mongodb-replicaset.yaml"
echo "  kubectl apply -f k8s/mongodb-services.yaml"
echo "  kubectl apply -f k8s/mongodb-users-secret.yaml"
echo "  kubectl apply -f k8s/mongodb-users.yaml"
