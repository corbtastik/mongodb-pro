# Terraform Usage Guide

This guide covers using Terraform to deploy MongoDB Enterprise with Ops Manager on macOS using OrbStack.

## Prerequisites

- **macOS** 15+ on Apple Silicon
- **OrbStack** installed and configured:
  - Rosetta enabled (Settings → System → Use Rosetta)
  - Memory limit: 16+ GB recommended
  - Kubernetes enabled (Settings → Kubernetes → Enable)
- **Terraform** 1.0+ installed (`brew install terraform`)
- **kubectl** configured for OrbStack Kubernetes
- **Helm** installed (`brew install helm`)
- **mongosh** installed for testing connections

## Directory Structure

```
terraform/
├── environments/
│   └── local/              # Local OrbStack environment
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars.example
│
└── modules/
    ├── ops-manager-local/  # VM, AppDB, Ops Manager, TLS
    ├── k8s-operator/       # MongoDB Enterprise K8s Operator
    └── mongodb-cluster/    # MongoDB deployments
```

## Quick Start

### Step 1: Initialize Terraform

```bash
cd terraform/environments/local
cp terraform.tfvars.example terraform.tfvars
terraform init
```

### Step 2: Deploy Ops Manager Infrastructure

On first run, leave the Ops Manager credentials empty in `terraform.tfvars`:

```hcl
ops_manager_org_id          = ""
ops_manager_api_public_key  = ""
ops_manager_api_private_key = ""
```

Run Terraform to deploy the infrastructure:

```bash
terraform apply
```

This will:
1. Create the OrbStack VM
2. Install MongoDB AppDB (3-node replica set)
3. Install Ops Manager 8.0
4. Configure TLS (HTTPS on port 8443)

### Step 3: Create Admin User and API Key (Manual)

1. Open https://opsmanager.orb.local:8443
2. Create admin user (first user becomes admin)
3. Complete the setup wizard
4. Create API Key:
   - Go to: Organization → Access Manager → API Keys
   - Description: "terraform"
   - Permissions: Organization Owner
   - Add to Access List: `192.168.215.0/24`
5. Copy the Organization ID, Public Key, and Private Key

### Step 4: Update Configuration

Edit `terraform.tfvars` with your API credentials:

```hcl
ops_manager_org_id          = "your-24-char-org-id"
ops_manager_api_public_key  = "your-public-key"
ops_manager_api_private_key = "your-private-key"
```

### Step 5: Deploy K8s Operator and MongoDB Cluster

```bash
terraform apply
```

This will:
1. Deploy the MongoDB Enterprise Kubernetes Operator
2. Create a project in Ops Manager
3. Deploy MongoDB clusters defined in `clusters` variable

### Step 6: Verify Deployment

```bash
# Check MongoDB status
kubectl get mongodb,pods -n mongodb-demo-01

# Connect to MongoDB
mongosh 'mongodb://dbAdmin:MongoDBPass123%21@192.168.139.2:30100/admin'
```

## Configuration Options

### Defining Clusters

Clusters are defined as a map in `terraform.tfvars`. Each key is the cluster/project name:

```hcl
clusters = {
  "demo-01" = {
    type = "Standalone"
  }
}
```

Deploy multiple clusters:

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

Cluster options:

| Option | Description | Default |
|--------|-------------|---------|
| `type` | `Standalone` or `ReplicaSet` | Required |
| `members` | ReplicaSet member count | `3` |
| `cpu_limit` | CPU limit per pod | `"2"` |
| `memory_limit` | Memory limit per pod | `"4Gi"` |
| `version` | Version trigger for recreation | `"1.0"` |

### Skip Cluster Deployment

Deploy only Ops Manager and the K8s operator (no clusters):

```hcl
clusters = {}
```

### Disable TLS

Run Ops Manager without TLS (HTTP only):

```hcl
enable_tls = false
```

### Force Resource Recreation

Increment version triggers to force recreation:

```hcl
vm_version          = "2.0"  # Recreate VM
ops_manager_version = "2.0"  # Reinstall Ops Manager

# Per-cluster version trigger
clusters = {
  "demo-01" = {
    type    = "Standalone"
    version = "2.0"  # Redeploy this cluster
  }
}
```

## Terraform Commands

```bash
# Initialize
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy everything
terraform destroy

# Show outputs
terraform output

# Format configuration
terraform fmt -recursive
```

## Outputs

After successful deployment:

| Output | Description |
|--------|-------------|
| `ops_manager_url` | Ops Manager URL (HTTP or HTTPS) |
| `tls_enabled` | Whether TLS is enabled |
| `clusters` | Map of deployed clusters with connection info |

Example output:

```
clusters = {
  "demo-01" = {
    cluster_name      = "demo-01"
    cluster_type      = "Standalone"
    connection_string = "mongodb://dbAdmin:MongoDBPass123%21@192.168.139.2:<nodeport>/admin"
    namespace         = "mongodb-demo-01"
  }
  "demo-02" = {
    cluster_name      = "demo-02"
    cluster_type      = "ReplicaSet"
    connection_string = "mongodb://dbAdmin:MongoDBPass123%21@192.168.139.2:<nodeport>/admin"
    namespace         = "mongodb-demo-02"
  }
}
```

## Troubleshooting

### Ops Manager not accessible

```bash
# Check VM status
orb list

# Check Ops Manager service
orb -m opsmanager -u root systemctl status mongodb-mms
```

### K8s Operator not starting

```bash
# Check operator logs
kubectl logs deployment/mongodb-enterprise-operator -n mongodb
```

### MongoDB cluster stuck in Pending

```bash
# Check operator logs for errors
kubectl logs deployment/mongodb-enterprise-operator -n mongodb --tail=50

# Describe MongoDB resource
kubectl describe mongodb demo-01 -n mongodb-demo-01
```

### Force clean restart

```bash
# Destroy everything via Terraform
terraform destroy

# Or use the teardown script
../../scripts/teardown.sh
```

## Module Reference

### ops-manager-local

Deploys Ops Manager infrastructure on OrbStack.

| Variable | Description | Default |
|----------|-------------|---------|
| `scripts_path` | Path to scripts directory | Required |
| `enable_tls` | Enable HTTPS | `true` |
| `vm_version` | Version trigger | `"1.0"` |

### k8s-operator

Deploys MongoDB Enterprise Kubernetes Operator.

| Variable | Description | Default |
|----------|-------------|---------|
| `ops_manager_url` | Ops Manager URL | Required |
| `ops_manager_org_id` | Organization ID | Required |
| `ops_manager_api_public_key` | API Public Key | Required |
| `ops_manager_api_private_key` | API Private Key | Required |

### mongodb-cluster

Deploys MongoDB clusters.

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project/cluster name | Required |
| `cluster_type` | `Standalone` or `ReplicaSet` | `"Standalone"` |
| `members` | ReplicaSet member count | `3` |
| `mongodb_version` | MongoDB version | `"8.0.0-ent"` |
| `cpu_limit` | CPU limit per pod | `"2"` |
| `memory_limit` | Memory limit per pod | `"4Gi"` |
