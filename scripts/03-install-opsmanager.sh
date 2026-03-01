#!/bin/bash
# Step 3: Install Ops Manager in the VM
set -e

VM_NAME="opsmanager"
OPS_MANAGER_VERSION="8.0.20.500.20260218T0837Z"
OPS_MANAGER_DEB="mongodb-mms-${OPS_MANAGER_VERSION}.amd64.deb"
OPS_MANAGER_URL="https://downloads.mongodb.com/on-prem-mms/deb/${OPS_MANAGER_DEB}"

echo "=== Installing Ops Manager 8.0 in VM: ${VM_NAME} ==="
echo ""

# Check if VM is running
if ! orb list 2>/dev/null | grep -q "^${VM_NAME} .*running"; then
    echo "ERROR: VM '$VM_NAME' is not running. Start it first."
    exit 1
fi

# Check if MongoDB AppDB is running (3-node replica set)
echo "=== Checking AppDB status ==="
if ! orb -m "$VM_NAME" systemctl is-active --quiet mongod-rs1; then
    echo "ERROR: MongoDB AppDB is not running. Run 02-install-appdb.sh first."
    exit 1
fi
echo "AppDB is running."

# Download and install Ops Manager
orb -m "$VM_NAME" -u root bash << INSTALL_SCRIPT
set -e

cd /tmp

# Check if already installed and running
if [ -f /opt/mongodb/mms/conf/conf-mms.properties ]; then
    if systemctl is-active --quiet mongodb-mms; then
        echo ""
        echo "Ops Manager is already installed and running."
        exit 0
    fi
fi

echo ""
echo "=== Downloading Ops Manager 8.0 ==="
if [ ! -f "${OPS_MANAGER_DEB}" ]; then
    curl -fSL -o "${OPS_MANAGER_DEB}" "${OPS_MANAGER_URL}"
else
    echo "Package already downloaded."
fi

echo ""
echo "=== Installing Ops Manager package ==="
dpkg -i "${OPS_MANAGER_DEB}"

echo ""
echo "=== Configuring system limits ==="
cat >> /etc/security/limits.conf << 'LIMITS'

# Ops Manager limits
mongodb-mms  soft    nofile    64000
mongodb-mms  hard    nofile    64000
mongodb-mms  soft    nproc     64000
mongodb-mms  hard    nproc     64000
LIMITS

# Add limits to systemd service
mkdir -p /etc/systemd/system/mongodb-mms.service.d
cat > /etc/systemd/system/mongodb-mms.service.d/limits.conf << 'SVC_LIMITS'
[Service]
LimitNOFILE=64000
LimitNPROC=64000
SVC_LIMITS
systemctl daemon-reload

echo ""
echo "=== Configuring Ops Manager ==="
# Backup original config
cp /opt/mongodb/mms/conf/conf-mms.properties /opt/mongodb/mms/conf/conf-mms.properties.orig

# Update mongo.mongoUri to use our 3-node replica set
# Remove the default mongo.mongoUri line and add our configuration
sed -i '/^mongo.mongoUri=/d' /opt/mongodb/mms/conf/conf-mms.properties

cat >> /opt/mongodb/mms/conf/conf-mms.properties << 'CONFIG'

# AppDB Connection (3-node replica set)
mongo.mongoUri=mongodb://localhost:27017,localhost:27018,localhost:27019/?replicaSet=appdbRS

# Central URL for Ops Manager (how agents connect)
mms.centralUrl=http://opsmanager.orb.local:8080
CONFIG

echo ""
echo "=== Setting ownership ==="
chown -R mongodb-mms:mongodb-mms /opt/mongodb/mms

echo ""
echo "=== Starting Ops Manager ==="
systemctl enable mongodb-mms
systemctl start mongodb-mms

echo ""
echo "Waiting for Ops Manager to initialize (this takes a while)..."
echo "Checking status every 10 seconds..."

# Wait for Ops Manager to be ready (check HTTP endpoint)
MAX_WAIT=300
WAITED=0
while [ \$WAITED -lt \$MAX_WAIT ]; do
    HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
    if [ "\$HTTP_CODE" = "200" ] || [ "\$HTTP_CODE" = "302" ] || [ "\$HTTP_CODE" = "303" ]; then
        echo ""
        echo "Ops Manager is ready! (HTTP \$HTTP_CODE)"
        break
    fi
    echo "  Still starting... (\${WAITED}s elapsed)"
    sleep 10
    WAITED=\$((WAITED + 10))
done

if [ \$WAITED -ge \$MAX_WAIT ]; then
    echo ""
    echo "WARNING: Ops Manager may still be starting."
    echo "Check logs with: journalctl -u mongodb-mms -f"
fi

INSTALL_SCRIPT

echo ""
echo "=== Verifying Ops Manager ==="
orb -m "$VM_NAME" -u root systemctl status mongodb-mms --no-pager | head -15

echo ""
echo "=== Installation complete ==="
echo ""
echo "Ops Manager URL: http://opsmanager.orb.local:8080"
echo ""
echo "Next steps:"
echo "  1. Open http://opsmanager.orb.local:8080 in your browser"
echo "  2. Complete the initial setup wizard"
echo "  3. Register for a free evaluation license"
echo ""
echo "View logs: orb -m $VM_NAME -u root journalctl -u mongodb-mms -f"
