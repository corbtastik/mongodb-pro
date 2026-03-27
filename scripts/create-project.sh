#!/bin/bash
# Create a new Project in an Ops Manager Organization
# Reads credentials from .env file
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env file only if environment variables are not already set
# This allows Terraform to pass values via environment variables
if [[ -z "$OPS_MANAGER_URL" ]] || [[ -z "$OPS_MANAGER_ORG_ID" ]] || \
   [[ -z "$OPS_MANAGER_API_PUBLIC_KEY" ]] || [[ -z "$OPS_MANAGER_API_PRIVATE_KEY" ]]; then
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    else
        echo "Error: .env file not found at $PROJECT_ROOT/.env"
        echo "Copy .env.example to .env and configure your credentials."
        exit 1
    fi
fi

# Validate required variables
if [[ -z "$OPS_MANAGER_URL" ]] || [[ -z "$OPS_MANAGER_ORG_ID" ]] || \
   [[ -z "$OPS_MANAGER_API_PUBLIC_KEY" ]] || [[ -z "$OPS_MANAGER_API_PRIVATE_KEY" ]]; then
    echo "Error: Missing required environment variables."
    echo "Ensure OPS_MANAGER_URL, OPS_MANAGER_ORG_ID, OPS_MANAGER_API_PUBLIC_KEY, and OPS_MANAGER_API_PRIVATE_KEY are set in .env"
    exit 1
fi

# Configure TLS options for curl
CURL_TLS_OPTS=""
if [[ "$OPS_MANAGER_URL" == https://* ]]; then
    CA_CERT="$SCRIPT_DIR/certs/ca.crt"
    if [[ -f "$CA_CERT" ]]; then
        CURL_TLS_OPTS="--cacert $CA_CERT"
    else
        # Fall back to insecure for self-signed certs without CA
        CURL_TLS_OPTS="-k"
    fi
fi

# Get project name from argument or prompt
PROJECT_NAME="${1:-}"
if [[ -z "$PROJECT_NAME" ]]; then
    read -p "Enter project name: " PROJECT_NAME
fi

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: Project name is required."
    exit 1
fi

echo "Creating project '$PROJECT_NAME' in organization '$OPS_MANAGER_ORG_ID'..."

# Create project via API
RESPONSE=$(curl -s -w "\n%{http_code}" \
    $CURL_TLS_OPTS \
    --digest \
    -u "${OPS_MANAGER_API_PUBLIC_KEY}:${OPS_MANAGER_API_PRIVATE_KEY}" \
    -H "Content-Type: application/json" \
    -X POST \
    "${OPS_MANAGER_URL}/api/public/v1.0/groups" \
    -d "{\"name\": \"${PROJECT_NAME}\", \"orgId\": \"${OPS_MANAGER_ORG_ID}\"}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "201" ]]; then
    PROJECT_ID=$(echo "$BODY" | grep -o '"id" *: *"[^"]*"' | head -1 | cut -d'"' -f4)
    echo ""
    echo "Project created successfully!"
    echo "  Name: $PROJECT_NAME"
    echo "  ID:   $PROJECT_ID"
    echo ""
    echo "To use this project with Kustomize:"
    echo "  1. Create a new overlay directory: k8s/overlays/$PROJECT_NAME/"
    echo "  2. Copy an existing overlay as a template"
    echo "  3. Update the projectName in the overlay's patches"
    echo ""
    echo "Example kustomization.yaml patch for this project:"
    echo "  - op: replace"
    echo "    path: /data/projectName"
    echo "    value: \"$PROJECT_NAME\""
else
    echo "Error creating project (HTTP $HTTP_CODE):"
    echo "$BODY"
    exit 1
fi
