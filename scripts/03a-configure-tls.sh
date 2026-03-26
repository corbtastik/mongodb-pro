#!/bin/bash
# Step 3a: Configure TLS for Ops Manager (Optional)
# Generates self-signed certificates and enables HTTPS on port 8443
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="opsmanager"
CERT_DIR="/etc/ssl/opsmanager"
CA_SUBJECT="/CN=MongoDB Demo CA/O=MongoDB Demo/C=US"
SERVER_SUBJECT="/CN=opsmanager.orb.local/O=MongoDB Demo/C=US"
CERT_DAYS=365

echo "=== Configuring TLS for Ops Manager ==="
echo ""

# Check if VM is running
if ! orb list 2>/dev/null | grep -q "^${VM_NAME} .*running"; then
    echo "ERROR: VM '$VM_NAME' is not running."
    exit 1
fi

# Check if Ops Manager is installed
if ! orb -m "$VM_NAME" -u root test -f /opt/mongodb/mms/conf/conf-mms.properties; then
    echo "ERROR: Ops Manager is not installed. Run 03-install-opsmanager.sh first."
    exit 1
fi

# Generate certificates and configure TLS
orb -m "$VM_NAME" -u root bash << CONFIGURE_TLS
set -e

echo "=== Creating certificate directory ==="
mkdir -p ${CERT_DIR}
cd ${CERT_DIR}

echo ""
echo "=== Generating Certificate Authority ==="
# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate
openssl req -new -x509 -days ${CERT_DAYS} -key ca.key -out ca.crt \
    -subj "${CA_SUBJECT}"

echo ""
echo "=== Generating Server Certificate ==="
# Generate server private key
openssl genrsa -out server.key 4096

# Create server certificate signing request
openssl req -new -key server.key -out server.csr \
    -subj "${SERVER_SUBJECT}"

# Create extensions file for SAN (Subject Alternative Names)
cat > server.ext << 'EXT'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = opsmanager.orb.local
DNS.2 = opsmanager
DNS.3 = localhost
IP.1 = 127.0.0.1
EXT

# Sign server certificate with CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days ${CERT_DAYS} -extfile server.ext

echo ""
echo "=== Creating PEM file for Ops Manager ==="
# Ops Manager needs cert + key in a single PEM file
cat server.crt server.key > server.pem

# Set permissions
chmod 600 *.key *.pem
chmod 644 *.crt
chown -R mongodb-mms:mongodb-mms ${CERT_DIR}

echo ""
echo "=== Updating Ops Manager configuration ==="

# Check if TLS is already configured
if grep -q "^mms.https.PEMKeyFile=" /opt/mongodb/mms/conf/conf-mms.properties; then
    echo "TLS already configured in conf-mms.properties"
else
    # Add TLS configuration
    cat >> /opt/mongodb/mms/conf/conf-mms.properties << CONFIG

# TLS Configuration (added by 03a-configure-tls.sh)
mms.https.PEMKeyFile=${CERT_DIR}/server.pem
mms.https.ClientCertificateMode=none
CONFIG
fi

# Update centralUrl to use HTTPS
sed -i 's|mms.centralUrl=http://opsmanager.orb.local:8080|mms.centralUrl=https://opsmanager.orb.local:8443|g' /opt/mongodb/mms/conf/conf-mms.properties

echo ""
echo "=== Restarting Ops Manager ==="
systemctl restart mongodb-mms

echo ""
echo "Waiting for Ops Manager to start with HTTPS..."

# Wait for HTTPS endpoint to be ready
MAX_WAIT=120
WAITED=0
while [ \$WAITED -lt \$MAX_WAIT ]; do
    # Use -k to accept self-signed cert
    HTTP_CODE=\$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:8443 2>/dev/null || echo "000")
    if [ "\$HTTP_CODE" = "200" ] || [ "\$HTTP_CODE" = "302" ] || [ "\$HTTP_CODE" = "303" ]; then
        echo ""
        echo "Ops Manager HTTPS is ready! (HTTP \$HTTP_CODE)"
        break
    fi
    echo "  Starting... (\${WAITED}s elapsed)"
    sleep 5
    WAITED=\$((WAITED + 5))
done

if [ \$WAITED -ge \$MAX_WAIT ]; then
    echo ""
    echo "WARNING: Ops Manager may still be starting."
    echo "Check logs with: journalctl -u mongodb-mms -f"
fi

echo ""
echo "=== Certificate Details ==="
openssl x509 -in ${CERT_DIR}/server.crt -noout -subject -issuer -dates

CONFIGURE_TLS

# Copy CA certificate to project directory for K8s operator use
echo ""
echo "=== Exporting CA certificate for Kubernetes ==="
CA_LOCAL_DIR="$SCRIPT_DIR/../certs"
mkdir -p "$CA_LOCAL_DIR"
orb -m "$VM_NAME" -u root cat ${CERT_DIR}/ca.crt > "$CA_LOCAL_DIR/ca.crt"
echo "CA certificate saved to: $CA_LOCAL_DIR/ca.crt"

echo ""
echo "=== TLS Configuration Complete ==="
echo ""
echo "Ops Manager URL: https://opsmanager.orb.local:8443"
echo ""
echo "IMPORTANT: Update your .env file:"
echo "  OPS_MANAGER_URL=https://opsmanager.orb.local:8443"
echo ""
echo "NOTE: Your browser will show a certificate warning because this is"
echo "      a self-signed certificate. This is expected for a demo environment."
echo ""
echo "Certificate files:"
echo "  VM (${CERT_DIR}):"
echo "    - ca.crt        : Certificate Authority"
echo "    - server.pem    : Server certificate + key (used by Ops Manager)"
echo "  Local (certs/):"
echo "    - ca.crt        : CA for Kubernetes operator (used by 04-setup-k8s-operator.sh)"
echo ""
echo "To view certificate: orb -m $VM_NAME -u root openssl x509 -in ${CERT_DIR}/server.crt -text -noout"
echo ""
