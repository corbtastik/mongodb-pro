#!/bin/bash
# Generate a new Kustomize overlay for a MongoDB deployment
# Usage: ./new-overlay.sh <project-name> [options]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 <project-name> [options]"
    echo ""
    echo "Options:"
    echo "  --type <Standalone|ReplicaSet>   MongoDB deployment type (default: Standalone)"
    echo "  --members <n>                    Number of members (default: 1 for Standalone, 3 for ReplicaSet)"
    echo "  --nodeport <port>                NodePort for external access (default: auto-assign)"
    echo "  --cpu-limit <cores>              CPU limit per pod (default: 2)"
    echo "  --memory-limit <size>            Memory limit per pod (default: 4Gi)"
    echo "  --org-id <id>                    Ops Manager Organization ID (reads from .env if not set)"
    echo ""
    echo "Examples:"
    echo "  $0 lab-03                                    # Standalone with defaults"
    echo "  $0 lab-04 --type ReplicaSet --members 3     # 3-node replica set"
    echo "  $0 lab-05 --nodeport 31500 --cpu-limit 4    # Custom resources"
    exit 1
}

# Default values
PROJECT_NAME=""
DEPLOY_TYPE="Standalone"
MEMBERS=""
NODEPORT=""
CPU_LIMIT="2"
MEMORY_LIMIT="4Gi"
ORG_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            DEPLOY_TYPE="$2"
            shift 2
            ;;
        --members)
            MEMBERS="$2"
            shift 2
            ;;
        --nodeport)
            NODEPORT="$2"
            shift 2
            ;;
        --cpu-limit)
            CPU_LIMIT="$2"
            shift 2
            ;;
        --memory-limit)
            MEMORY_LIMIT="$2"
            shift 2
            ;;
        --org-id)
            ORG_ID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$PROJECT_NAME" ]]; then
                PROJECT_NAME="$1"
            else
                echo "Unknown option: $1"
                usage
            fi
            shift
            ;;
    esac
done

if [[ -z "$PROJECT_NAME" ]]; then
    usage
fi

# Load .env for ORG_ID if not provided
if [[ -z "$ORG_ID" ]]; then
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
        ORG_ID="${OPS_MANAGER_ORG_ID:-}"
    fi
fi

if [[ -z "$ORG_ID" ]]; then
    echo "Error: Organization ID not found. Provide --org-id or set OPS_MANAGER_ORG_ID in .env"
    exit 1
fi

# Set default members based on type
if [[ -z "$MEMBERS" ]]; then
    if [[ "$DEPLOY_TYPE" == "ReplicaSet" ]]; then
        MEMBERS=3
    else
        MEMBERS=1
    fi
fi

# Auto-assign nodeport if not provided (find next available in 31000-32000 range)
if [[ -z "$NODEPORT" ]]; then
    EXISTING_PORTS=$(grep -r "nodePort:" "$PROJECT_ROOT/k8s/overlays" 2>/dev/null | grep -oE '[0-9]+' | sort -n)
    NODEPORT=31000
    while echo "$EXISTING_PORTS" | grep -q "^${NODEPORT}$"; do
        ((NODEPORT++))
    done
fi

# Generate deployment name from project name
DEPLOY_NAME="${PROJECT_NAME}"

OVERLAY_DIR="$PROJECT_ROOT/k8s/overlays/$PROJECT_NAME"

if [[ -d "$OVERLAY_DIR" ]]; then
    echo "Error: Overlay '$PROJECT_NAME' already exists at $OVERLAY_DIR"
    exit 1
fi

echo "Creating Kustomize overlay for '$PROJECT_NAME'..."
echo "  Type:      $DEPLOY_TYPE"
echo "  Members:   $MEMBERS"
echo "  NodePort:  $NODEPORT"
echo "  CPU:       $CPU_LIMIT"
echo "  Memory:    $MEMORY_LIMIT"
echo "  Org ID:    $ORG_ID"
echo ""

mkdir -p "$OVERLAY_DIR"

# Generate kustomization.yaml
cat > "$OVERLAY_DIR/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: mongodb

resources:
  - ../../base

patches:
  # Patch MongoDB deployment
  - target:
      kind: MongoDB
      name: mongodb-deployment
    patch: |-
      - op: replace
        path: /metadata/name
        value: ${DEPLOY_NAME}
      - op: replace
        path: /spec/type
        value: ${DEPLOY_TYPE}
      - op: replace
        path: /spec/members
        value: ${MEMBERS}
      - op: replace
        path: /spec/opsManager/configMapRef/name
        value: ops-manager-connection-${PROJECT_NAME}
      - op: replace
        path: /spec/podSpec/podTemplate/spec/containers/0/resources/limits/cpu
        value: "${CPU_LIMIT}"
      - op: replace
        path: /spec/podSpec/podTemplate/spec/containers/0/resources/limits/memory
        value: ${MEMORY_LIMIT}

  # Patch Ops Manager ConfigMap
  - target:
      kind: ConfigMap
      name: ops-manager-connection
    patch: |-
      - op: replace
        path: /metadata/name
        value: ops-manager-connection-${PROJECT_NAME}
      - op: replace
        path: /data/orgId
        value: "${ORG_ID}"
      - op: replace
        path: /data/projectName
        value: "${PROJECT_NAME}"

  # Patch Service
  - target:
      kind: Service
      name: mongodb-external
    patch: |-
      - op: replace
        path: /metadata/name
        value: ${DEPLOY_NAME}-external
      - op: replace
        path: /spec/selector/app
        value: ${DEPLOY_NAME}-svc
      - op: replace
        path: /spec/ports/0/nodePort
        value: ${NODEPORT}

  # Patch MongoDBUser resources
  - target:
      kind: MongoDBUser
      name: dbuser
    patch: |-
      - op: replace
        path: /metadata/name
        value: dbuser-${PROJECT_NAME}
      - op: replace
        path: /spec/mongodbResourceRef/name
        value: ${DEPLOY_NAME}

  - target:
      kind: MongoDBUser
      name: dbadmin
    patch: |-
      - op: replace
        path: /metadata/name
        value: dbadmin-${PROJECT_NAME}
      - op: replace
        path: /spec/mongodbResourceRef/name
        value: ${DEPLOY_NAME}

  - target:
      kind: MongoDBUser
      name: sysadmin
    patch: |-
      - op: replace
        path: /metadata/name
        value: sysadmin-${PROJECT_NAME}
      - op: replace
        path: /spec/mongodbResourceRef/name
        value: ${DEPLOY_NAME}
EOF

echo "Overlay created at: $OVERLAY_DIR"
echo ""
echo "To preview the generated resources:"
echo "  kubectl kustomize k8s/overlays/$PROJECT_NAME"
echo ""
echo "To deploy:"
echo "  kubectl apply -k k8s/overlays/$PROJECT_NAME"
echo ""
echo "NOTE: Make sure project '$PROJECT_NAME' exists in Ops Manager first:"
echo "  ./scripts/create-project.sh $PROJECT_NAME"
