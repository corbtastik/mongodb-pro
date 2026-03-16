#!/bin/bash
# Create a new Organization in Ops Manager
#
# NOTE: This script requires USER authentication, not API key authentication.
# API keys cannot create organizations in Ops Manager.
#
# Organizations are typically created once during initial setup via the UI.
# For automation, use create-project.sh to create projects within an existing org.
#
# To create organizations programmatically, you would need to:
# 1. Use the Ops Manager UI (recommended for initial setup)
# 2. Use user credentials with HTTP Digest auth (not API keys)
# 3. Use LDAP/SSO integration with appropriate permissions
#
set -e

echo "ERROR: Organizations cannot be created via API keys."
echo ""
echo "Ops Manager requires user authentication (not API keys) to create organizations."
echo "Organizations are typically a one-time admin setup."
echo ""
echo "Options:"
echo "  1. Create organizations in the Ops Manager UI"
echo "     http://opsmanager.orb.local:8080"
echo ""
echo "  2. Use create-project.sh to create projects within an existing org"
echo "     ./scripts/create-project.sh <project-name>"
echo ""
exit 1
