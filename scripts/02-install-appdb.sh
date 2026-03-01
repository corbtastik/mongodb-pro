#!/bin/bash
# Step 2: Install MongoDB AppDB in the VM
# Sets up a 3-node replica set on ports 27017, 27018, 27019 (all in same VM)
set -e

VM_NAME="opsmanager"
MONGODB_VERSION="8.0"

echo "=== Installing MongoDB ${MONGODB_VERSION} AppDB (3-node RS) in VM: ${VM_NAME} ==="
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
if [ ! -f /usr/share/keyrings/mongodb-server-8.0.gpg ]; then
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
        gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
fi

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
echo "=== Configuring system limits ==="
cat >> /etc/security/limits.conf << 'LIMITS'

# MongoDB limits
mongodb      soft    nofile    64000
mongodb      hard    nofile    64000
mongodb      soft    nproc     64000
mongodb      hard    nproc     64000
LIMITS

echo ""
echo "=== Stopping default mongod service ==="
systemctl stop mongod 2>/dev/null || true
systemctl disable mongod 2>/dev/null || true

echo ""
echo "=== Creating directories for 3-node replica set ==="
for i in 1 2 3; do
    mkdir -p /var/lib/mongodb/rs${i}
    mkdir -p /var/log/mongodb
    chown -R mongodb:mongodb /var/lib/mongodb/rs${i}
done
chown -R mongodb:mongodb /var/log/mongodb

echo ""
echo "=== Creating mongod config files ==="

# Node 1 - port 27017
cat > /etc/mongod-rs1.conf << 'EOF'
storage:
  dbPath: /var/lib/mongodb/rs1
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod-rs1.log
net:
  port: 27017
  bindIp: 0.0.0.0
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
replication:
  replSetName: appdbRS
EOF

# Node 2 - port 27018
cat > /etc/mongod-rs2.conf << 'EOF'
storage:
  dbPath: /var/lib/mongodb/rs2
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod-rs2.log
net:
  port: 27018
  bindIp: 0.0.0.0
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
replication:
  replSetName: appdbRS
EOF

# Node 3 - port 27019
cat > /etc/mongod-rs3.conf << 'EOF'
storage:
  dbPath: /var/lib/mongodb/rs3
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod-rs3.log
net:
  port: 27019
  bindIp: 0.0.0.0
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
replication:
  replSetName: appdbRS
EOF

echo ""
echo "=== Creating systemd service files ==="

for i in 1 2 3; do
    port=$((27016 + i))
    cat > /etc/systemd/system/mongod-rs${i}.service << EOF
[Unit]
Description=MongoDB Database Server (RS Node ${i})
Documentation=https://docs.mongodb.org/manual
After=network-online.target
Wants=network-online.target

[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --config /etc/mongod-rs${i}.conf
RuntimeDirectory=mongodb
PIDFile=/var/run/mongodb/mongod-rs${i}.pid
LimitNOFILE=64000
LimitNPROC=64000

[Install]
WantedBy=multi-user.target
EOF
done

systemctl daemon-reload

echo ""
echo "=== Starting all 3 MongoDB nodes ==="
for i in 1 2 3; do
    systemctl enable mongod-rs${i}
    systemctl start mongod-rs${i}
    echo "Started mongod-rs${i}"
done

echo "Waiting for nodes to start..."
sleep 5

# Verify all nodes are running
for i in 1 2 3; do
    if ! systemctl is-active --quiet mongod-rs${i}; then
        echo "ERROR: mongod-rs${i} failed to start"
        journalctl -u mongod-rs${i} --no-pager -n 20
        exit 1
    fi
done
echo "All nodes running."

echo ""
echo "=== Initializing replica set ==="
# Check if already initialized
RS_STATUS=$(mongosh --port 27017 --quiet --eval "try { rs.status().ok } catch(e) { 0 }" 2>/dev/null || echo "0")

if [ "$RS_STATUS" = "1" ]; then
    echo "Replica set already initialized."
else
    echo "Initializing replica set 'appdbRS' with 3 members..."
    mongosh --port 27017 --quiet --eval '
        rs.initiate({
            _id: "appdbRS",
            members: [
                { _id: 0, host: "localhost:27017" },
                { _id: 1, host: "localhost:27018" },
                { _id: 2, host: "localhost:27019" }
            ]
        })
    '

    # Wait for replica set to elect primary
    echo "Waiting for primary election..."
    sleep 10
fi

echo ""
echo "=== Verifying replica set status ==="
mongosh --port 27017 --quiet --eval 'rs.status().members.forEach(m => print(m.name + " - " + m.stateStr))'

echo ""
echo "=== MongoDB version ==="
mongod --version | head -1

INSTALL_SCRIPT

echo ""
echo "=== AppDB installation complete ==="
echo "MongoDB 3-node replica set 'appdbRS' running on ports 27017, 27018, 27019"
echo "Connection string: mongodb://opsmanager.orb.local:27017,opsmanager.orb.local:27018,opsmanager.orb.local:27019/?replicaSet=appdbRS"
