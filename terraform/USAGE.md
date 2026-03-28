# Terraform Usage Guide

Deploy MongoDB Enterprise with Ops Manager on macOS using OrbStack and Terraform.

## Overview

This guide provides Infrastructure-as-Code deployment of MongoDB Enterprise using Terraform. The configuration is split into two independent modules:

| Module | Purpose | Lifecycle |
|--------|---------|-----------|
| **control-plane** | Ops Manager, AppDB, K8s Operator | Changes rarely |
| **data-plane** | MongoDB clusters | Changes often |

**Benefits of this separation:**
- Destroy/recreate clusters without affecting Ops Manager
- Independent state management
- Smaller blast radius for changes
- Supports team workflows (platform team vs app teams)

## Directory Structure

```
terraform/
├── control-plane/
│   └── local/                  # Ops Manager + K8s Operator
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars
│
├── data-plane/
│   └── local/                  # MongoDB clusters
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars
│
└── modules/
    ├── ops-manager-local/      # VM, AppDB, Ops Manager, TLS
    ├── k8s-operator/           # MongoDB Enterprise K8s Operator
    └── mongodb-cluster/        # MongoDB deployments
```

## Prerequisites

Before starting, ensure you have:

- **macOS** 15+ on Apple Silicon
- **OrbStack** installed and configured:
  - Rosetta enabled: Settings → System → Use Rosetta
  - Memory: 16+ GB recommended (Settings → System → Memory)
  - Kubernetes enabled: Settings → Kubernetes → Enable
- **Terraform** 1.0+ installed: `brew install terraform`
- **kubectl** configured for OrbStack (automatic with OrbStack)
- **Helm** installed: `brew install helm`
- **mongosh** (optional, for testing): `brew install mongosh`

---

## Detailed Step-by-Step Deployment

### Phase 1: Deploy Control Plane Infrastructure

#### Step 1.1: Navigate to Control Plane Directory

```bash
cd terraform/control-plane/local
```

#### Step 1.2: Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
```

#### Step 1.3: Initialize Terraform

```bash
terraform init
```

You should see: `Terraform has been successfully initialized!`

#### Step 1.4: Deploy Ops Manager Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will:
- Create an OrbStack VM (Ubuntu 22.04, x86_64 via Rosetta)
- Install MongoDB 8.0 AppDB (3-node replica set)
- Install Ops Manager 8.0
- Configure TLS with self-signed certificates

**Duration:** Approximately 5-10 minutes.

#### Step 1.5: Verify Ops Manager is Running

```bash
# Check VM is running
orb list

# Check Ops Manager service
orb -m opsmanager -u root systemctl status mongodb-mms
```

---

### Phase 2: Configure Ops Manager (Manual Steps)

#### Step 2.1: Open Ops Manager in Browser

Navigate to: **https://opsmanager.orb.local:8443**

> Note: Your browser will show a certificate warning because we're using a self-signed certificate. Click "Advanced" → "Proceed" to continue.

#### Step 2.2: Create Admin User

1. Click **Register** or **Sign Up**
2. Fill in your details:
   - Email: `admin@example.com` (or your email)
   - Password: Choose a secure password
   - First/Last Name: Your name
3. Click **Register**

#### Step 2.3: Complete Setup Wizard

1. **Welcome Page**: Click **Continue**
2. **Configure Settings**: Accept defaults or configure as needed
3. **Create Organization**: Enter a name (e.g., `demo-org`)
4. Click **Create Organization**

#### Step 2.4: Create API Key

1. In the left navigation, click your **Organization name**
2. Go to **Access Manager** → **API Keys**
3. Click **Create API Key**
4. Configure the key:
   - **Description**: `terraform`
   - **Organization Permissions**: Select **Organization Owner**
5. Click **Next**
6. **Save your keys** - copy both:
   - **Public Key**: (e.g., `abcdefgh`)
   - **Private Key**: (e.g., `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
7. Click **Add Access List Entry**
8. Enter CIDR: `192.168.215.0/24`
9. Click **Save**

#### Step 2.5: Get Organization ID

1. Go to **Organization** → **Settings**
2. Copy the **Organization ID** (24-character string)

---

### Phase 3: Deploy Kubernetes Operator

#### Step 3.1: Update Control Plane Configuration

Edit `terraform.tfvars` and add your credentials:

```hcl
enable_tls = true

ops_manager_org_id          = "your-24-character-org-id"
ops_manager_api_public_key  = "your-public-key"
ops_manager_api_private_key = "your-private-key"
```

#### Step 3.2: Deploy the K8s Operator

```bash
terraform apply
```

Type `yes` when prompted. This will deploy the MongoDB Enterprise Kubernetes Operator.

#### Step 3.3: Verify Operator is Running

```bash
kubectl get pods -n mongodb
```

You should see the operator pod in `Running` state:
```
NAME                                           READY   STATUS    RESTARTS   AGE
mongodb-enterprise-operator-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

---

### Phase 4: Deploy MongoDB Clusters

#### Step 4.1: Navigate to Data Plane Directory

```bash
cd ../../data-plane/local
```

#### Step 4.2: Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
```

#### Step 4.3: Configure Your Clusters

Edit `terraform.tfvars` to define your clusters:

```hcl
clusters = {
  "demo-01" = {
    type = "Standalone"
  }
}
```

Or for multiple clusters:

```hcl
clusters = {
  "demo-01" = {
    type = "Standalone"
  }
  "demo-02" = {
    type    = "ReplicaSet"
    members = 3
  }
}
```

> **Note:** Ops Manager credentials are automatically read from the control-plane state. No need to copy them.

#### Step 4.4: Initialize and Deploy

```bash
terraform init
terraform apply
```

Type `yes` when prompted.

#### Step 4.5: Verify Deployment

```bash
# Check all MongoDB resources
kubectl get mongodb -A

# Check pods for a specific cluster
kubectl get pods -n mongodb-demo-01

# Watch deployment progress
kubectl get pods -n mongodb-demo-01 -w
```

Wait for the MongoDB pod to show `Running` status.

#### Step 4.6: Connect to MongoDB

```bash
mongosh 'mongodb://dbAdmin:MongoDBPass123%21@192.168.139.2:30100/admin'
```

---

## Managing Clusters

### Add a New Cluster

Edit `data-plane/local/terraform.tfvars`:

```hcl
clusters = {
  "demo-01" = { type = "Standalone" }
  "demo-02" = { type = "ReplicaSet", members = 3 }
  "demo-03" = { type = "ReplicaSet", members = 5 }  # New cluster
}
```

```bash
terraform apply
```

### Remove a Cluster

Remove it from the clusters map and apply:

```bash
terraform apply
```

### Destroy All Clusters (Keep Control Plane)

```bash
cd terraform/data-plane/local
terraform destroy
```

### Destroy Everything

```bash
# Destroy data-plane first
cd terraform/data-plane/local
terraform destroy

# Then destroy control-plane
cd ../../control-plane/local
terraform destroy
```

---

## Configuration Reference

### Control Plane Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_tls` | Enable HTTPS for Ops Manager | `true` |
| `ops_manager_org_id` | Organization ID | `""` |
| `ops_manager_api_public_key` | API Public Key | `""` |
| `ops_manager_api_private_key` | API Private Key | `""` |
| `vm_version` | Trigger VM recreation | `"1.0"` |
| `appdb_version` | Trigger AppDB reinstall | `"1.0"` |
| `ops_manager_version` | Trigger Ops Manager reinstall | `"1.0"` |
| `tls_version` | Trigger TLS reconfiguration | `"1.0"` |
| `operator_version` | Trigger operator redeployment | `"1.0"` |

### Data Plane Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `clusters` | Map of clusters to deploy | `{}` |

> **Note:** Ops Manager credentials are automatically read from the control-plane state file.

### Cluster Configuration Options

```hcl
clusters = {
  "cluster-name" = {
    type         = "Standalone"  # or "ReplicaSet"
    members      = 3             # ReplicaSet only, default 3
    cpu_limit    = "2"           # CPU per pod, default "2"
    memory_limit = "4Gi"         # Memory per pod, default "4Gi"
    version      = "1.0"         # Increment to force recreation
  }
}
```

---

## Troubleshooting

### Ops Manager not accessible

```bash
# Check VM status
orb list

# Check Ops Manager service
orb -m opsmanager -u root systemctl status mongodb-mms

# Check Ops Manager logs
orb -m opsmanager -u root tail -100 /opt/mongodb/mms/logs/mms0.log
```

### K8s Operator not starting

```bash
# Check operator logs
kubectl logs deployment/mongodb-enterprise-operator -n mongodb

# Check operator events
kubectl describe deployment mongodb-enterprise-operator -n mongodb
```

### Cluster stuck in Pending

```bash
# Check MongoDB resource status
kubectl describe mongodb <cluster-name> -n mongodb-<cluster-name>

# Check operator logs for errors
kubectl logs deployment/mongodb-enterprise-operator -n mongodb --tail=50
```

### Authentication errors (401/403)

- Verify API key has **Organization Owner** permissions
- Ensure `192.168.215.0/24` is in the API key access list
- Regenerate API key if needed

---

## Quick Reference (Live Demo)

### Complete Teardown

```bash
cd /Users/corbs/dev/github/corbtastik/mongodb-pro
./scripts/teardown.sh
rm -rf terraform/control-plane/local/.terraform* terraform/control-plane/local/terraform.tfstate*
rm -rf terraform/data-plane/local/.terraform* terraform/data-plane/local/terraform.tfstate*
```

### Quick Deploy

```bash
# Control Plane
cd terraform/control-plane/local
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# >>> Manual: Configure Ops Manager UI, create API key <<<
# >>> Edit terraform.tfvars with credentials <<<

terraform apply

# Data Plane
cd ../../data-plane/local
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - define clusters
terraform init && terraform apply

# Verify
kubectl get mongodb -A
```

### Quick Commands

```bash
# Check status
kubectl get mongodb -A
kubectl get pods -n mongodb-demo-01

# Connect to MongoDB
mongosh 'mongodb://dbAdmin:MongoDBPass123%21@192.168.139.2:30100/admin'

# Destroy clusters only (keep Ops Manager)
cd terraform/data-plane/local && terraform destroy

# Destroy everything
cd terraform/data-plane/local && terraform destroy
cd ../../control-plane/local && terraform destroy
```
