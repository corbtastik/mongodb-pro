#!/bin/bash
# Load sample telco data into MongoDB
# Usage: ./load-sample-data.sh <project-name>
set -e

PROJECT_NAME="${1:-}"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Usage: $0 <project-name>"
    echo ""
    echo "Example:"
    echo "  $0 demo-standalone"
    exit 1
fi

NAMESPACE="mongodb-${PROJECT_NAME}"

# Get NodePort
NODEPORT=$(kubectl get svc "${PROJECT_NAME}-external" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

if [[ -z "$NODEPORT" ]]; then
    echo "Error: Service '${PROJECT_NAME}-external' not found"
    exit 1
fi

CONNECTION_STRING="mongodb://dbUser:MongoDBPass123!@192.168.139.2:${NODEPORT}/admin"

echo "Loading sample telco data into: $PROJECT_NAME"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mongosh "$CONNECTION_STRING" --quiet "$SCRIPT_DIR/sample-data.js"

echo ""
echo "Done! Connect and explore:"
echo "  mongosh '$CONNECTION_STRING'"
echo "  use telco"
echo "  db.subscribers.find()"
