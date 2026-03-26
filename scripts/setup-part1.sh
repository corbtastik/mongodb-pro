#!/bin/bash
# Part 1: Infrastructure Setup
# Creates VM, installs AppDB, Ops Manager, and configures TLS
# After this completes, configure Ops Manager in the UI before running Part 2
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Part 1: Infrastructure Setup ==="
echo ""

# Step 1: Create VM
echo ">>> Step 1/4: Creating Ops Manager VM..."
"$SCRIPT_DIR/01-create-opsmanager-vm.sh"

# Step 2: Install AppDB
echo ""
echo ">>> Step 2/4: Installing MongoDB AppDB..."
"$SCRIPT_DIR/02-install-appdb.sh"

# Step 3: Install Ops Manager
echo ""
echo ">>> Step 3/4: Installing Ops Manager..."
"$SCRIPT_DIR/03-install-opsmanager.sh"

# Step 4: Configure TLS
echo ""
echo ">>> Step 4/4: Configuring TLS..."
"$SCRIPT_DIR/03a-configure-tls.sh"

echo ""
echo "=== Part 1 Complete ==="
echo ""
echo "Next steps:"
echo "  1. Open https://opsmanager.orb.local:8443"
echo "  2. Create admin user"
echo "  3. Create organization"
echo "  4. Create API key (Organization Owner, add 192.168.139.0/24 to access list)"
echo "  5. Update .env with HTTPS URL and credentials"
echo "  6. Run: ./scripts/setup-part2.sh"
echo ""
