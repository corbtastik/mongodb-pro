#!/bin/bash
# Step 1: Create and provision the Ops Manager VM
set -e

VM_NAME="opsmanager"
DISTRO="ubuntu:22.04"
ARCH="amd64"

echo "=== Creating Ops Manager VM ==="
echo "VM Name: $VM_NAME"
echo "Distro:  $DISTRO"
echo "Arch:    $ARCH (x86_64 via Rosetta)"
echo ""

# Check if VM already exists
if orb list 2>/dev/null | grep -q "^${VM_NAME} "; then
    echo "VM '$VM_NAME' already exists."
    orb info "$VM_NAME"
    exit 0
fi

# Create the x86_64 Ubuntu 22.04 VM
echo "Creating VM..."
orb create -a "$ARCH" "$DISTRO" "$VM_NAME"

# Wait for VM to be ready
echo "Waiting for VM to start..."
sleep 5

# Verify the VM is running
echo ""
echo "=== Verifying VM ==="
orb info "$VM_NAME"

# Verify architecture inside the VM
echo ""
echo "=== Checking architecture inside VM ==="
orb -m "$VM_NAME" uname -m

# Basic system info
echo ""
echo "=== System info ==="
orb -m "$VM_NAME" cat /etc/os-release | grep -E "^(NAME|VERSION)="

echo ""
echo "=== VM created successfully ==="
echo "Access via: orb -m $VM_NAME"
echo "SSH:        ssh ${VM_NAME}@orb"
echo "Hostname:   ${VM_NAME}.orb.local"