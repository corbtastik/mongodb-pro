#!/bin/bash
# Get MongoDB connection string for a deployment
# Usage: ./get-connection-string.sh <project-name>
set -e

PROJECT_NAME="${1:-}"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Usage: $0 <project-name>"
    echo ""
    echo "Examples:"
    echo "  $0 demo-standalone"
    echo "  $0 dev-01"
    exit 1
fi

NAMESPACE="mongodb-${PROJECT_NAME}"

# Check namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "Error: Namespace '$NAMESPACE' not found"
    exit 1
fi

# Get NodePort
NODEPORT=$(kubectl get svc "${PROJECT_NAME}-external" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

if [[ -z "$NODEPORT" ]]; then
    echo "Error: Service '${PROJECT_NAME}-external' not found in namespace '$NAMESPACE'"
    exit 1
fi

echo ""
echo "Connection strings for: $PROJECT_NAME"
echo ""
echo "# dbUser (application user)"
echo "mongosh 'mongodb://dbUser:MongoDBPass123!@192.168.139.2:${NODEPORT}/admin'"
echo ""
echo "# dbAdmin (database admin)"
echo "mongosh 'mongodb://dbAdmin:MongoDBPass123!@192.168.139.2:${NODEPORT}/admin'"
echo ""
echo "# sysAdmin (superuser)"
echo "mongosh 'mongodb://sysAdmin:MongoDBPass123!@192.168.139.2:${NODEPORT}/admin'"
echo ""
