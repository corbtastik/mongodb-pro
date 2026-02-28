#!/bin/bash
# Step 2: Install MongoDB AppDB in the VM
set -e

VM_NAME="opsmanager"
MONGODB_VERSION="8.0"

echo "=== Installing MongoDB ${MONGODB_VERSION} AppDB in VM: ${VM_NAME} ==="
echo ""

# Check if VM is running
if ! orb list 2>/dev/null | grep -q "^${VM_NAME} .*running"; then
    echo "ERROR: VM '$VM_NAME' is not running. Start it first."
    exit 1
fi

# Run installation inside the VM
orb -m "$VM_NAME" -u root bash << 'INSTALL_SCRIPT'
set -e

echo "=== Updating package lists ==="
apt-get update

echo ""
echo "=== Installing prerequisites ==="
apt-get install -y gnupg curl

echo ""
echo "=== Adding MongoDB GPG key ==="
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
    gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg

echo ""
echo "=== Adding MongoDB 8.0 repository ==="
echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-8.0.list

echo ""
echo "=== Updating package lists with MongoDB repo ==="
apt-get update

echo ""
echo "=== Installing MongoDB 8.0 ==="
apt-get install -y mongodb-org

echo ""
echo "=== Creating data directory ==="
mkdir -p /var/lib/mongodb
chown -R mongodb:mongodb /var/lib/mongodb

echo ""
echo "=== Creating log directory ==="
mkdir -p /var/log/mongodb
chown -R mongodb:mongodb /var/log/mongodb

INSTALL_SCRIPT

echo ""
echo "=== Copying mongod configuration ==="
# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Copy the mongod.conf to the VM
orb push -m "$VM_NAME" "$PROJECT_DIR/config/mongod.conf" /tmp/mongod.conf
orb -m "$VM_NAME" -u root bash -c "mv /tmp/mongod.conf /etc/mongod.conf && chown root:root /etc/mongod.conf"

# Start MongoDB and initialize replica set
orb -m "$VM_NAME" -u root bash << 'START_SCRIPT'
set -e

echo ""
echo "=== Starting MongoDB ==="
systemctl enable mongod
systemctl start mongod

echo "Waiting for MongoDB to start..."
sleep 5

# Check if mongod is running
if ! systemctl is-active --quiet mongod; then
    echo "ERROR: MongoDB failed to start"
    journalctl -u mongod --no-pager -n 50
    exit 1
fi

echo ""
echo "=== Initializing replica set ==="
# Check if already initialized
RS_STATUS=$(mongosh --quiet --eval "try { rs.status().ok } catch(e) { 0 }" 2>/dev/null || echo "0")

if [ "$RS_STATUS" = "1" ]; then
    echo "Replica set already initialized."
else
    echo "Initializing replica set 'appdbRS'..."
    mongosh --quiet --eval '
        rs.initiate({
            _id: "appdbRS",
            members: [{ _id: 0, host: "localhost:27017" }]
        })
    '

    # Wait for replica set to elect primary
    echo "Waiting for primary election..."
    sleep 5
fi

echo ""
echo "=== Verifying replica set status ==="
mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name + " - " + m.stateStr))'

echo ""
echo "=== MongoDB version ==="
mongod --version | head -1

START_SCRIPT

echo ""
echo "=== AppDB installation complete ==="
echo "MongoDB is running as replica set 'appdbRS' on ${VM_NAME}:27017"
echo "Connection string: mongodb://${VM_NAME}.orb.local:27017/?replicaSet=appdbRS"