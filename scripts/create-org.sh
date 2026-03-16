#!/bin/bash
# Create a new Organization in Ops Manager
# Reads credentials from .env file
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env file
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    source "$PROJECT_ROOT/.env"
else
    echo "Error: .env file not found at $PROJECT_ROOT/.env"
    echo "Copy .env.example to .env and configure your credentials."
    exit 1
fi

# Validate required variables
if [[ -z "$OPS_MANAGER_URL" ]] || [[ -z "$OPS_MANAGER_API_PUBLIC_KEY" ]] || [[ -z "$OPS_MANAGER_API_PRIVATE_KEY" ]]; then
    echo "Error: Missing required environment variables."
    echo "Ensure OPS_MANAGER_URL, OPS_MANAGER_API_PUBLIC_KEY, and OPS_MANAGER_API_PRIVATE_KEY are set in .env"
    exit 1
fi

# Get org name from argument or prompt
ORG_NAME="${1:-}"
if [[ -z "$ORG_NAME" ]]; then
    read -p "Enter organization name: " ORG_NAME
fi

if [[ -z "$ORG_NAME" ]]; then
    echo "Error: Organization name is required."
    exit 1
fi

echo "Creating organization '$ORG_NAME' in Ops Manager..."

# Create organization via API
RESPONSE=$(curl -s -w "\n%{http_code}" \
    --digest \
    -u "${OPS_MANAGER_API_PUBLIC_KEY}:${OPS_MANAGER_API_PRIVATE_KEY}" \
    -H "Content-Type: application/json" \
    -X POST \
    "${OPS_MANAGER_URL}/api/public/v1.0/orgs" \
    -d "{\"name\": \"${ORG_NAME}\"}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "201" ]]; then
    ORG_ID=$(echo "$BODY" | grep -o '"id" *: *"[^"]*"' | head -1 | cut -d'"' -f4)
    echo ""
    echo "Organization created successfully!"
    echo "  Name: $ORG_NAME"
    echo "  ID:   $ORG_ID"
    echo ""
    echo "Update your .env file:"
    echo "  OPS_MANAGER_ORG_ID=$ORG_ID"
    echo ""
    echo "Next steps:"
    echo "  1. Create an API key for this org in Ops Manager UI"
    echo "  2. Add IP access list: 192.168.139.0/24"
    echo "  3. Update .env with the new API key credentials"
    echo "  4. Run ./scripts/create-project.sh to create projects"
else
    echo "Error creating organization (HTTP $HTTP_CODE):"
    echo "$BODY"
    exit 1
fi
