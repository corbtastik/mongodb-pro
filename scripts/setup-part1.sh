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
echo "=== Ops Manager Setup Complete ==="
echo ""
