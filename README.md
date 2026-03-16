# mongodb-pro

Local MongoDB Enterprise environment with Ops Manager and Kubernetes Operator on macOS (Apple Silicon).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  macOS (Apple Silicon M4 Max, 128GB RAM)                    │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  OrbStack (Apple Virtualization.framework)            │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  VM: opsmanager (Ubuntu 22.04, x86_64 Rosetta)  │  │  │
│  │  │  - MongoDB 8.0 AppDB (3-node replica set)       │  │  │
│  │  │  - Ops Manager 8.0.20                           │  │  │
│  │  │  - http://opsmanager.orb.local:8080             │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Kubernetes (OrbStack built-in)                 │  │  │
│  │  │  - MongoDB Enterprise Kubernetes Operator       │  │  │
│  │  │  - demo-standalone (MongoDB 8.0, 2 CPU, 4Gi)    │  │  │
│  │  │  - demo-rs (3-node RS, 6 CPU total, 12Gi)       │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- macOS 15+ on Apple Silicon
- OrbStack installed with Rosetta enabled
- OrbStack memory limit: 16+ GB recommended (Settings → System → Memory)
- `kubectl` available (bundled with OrbStack)

## Key Constraints

- **Ops Manager is x86_64 only** - runs in OrbStack VM via Rosetta
- **Ops Manager requires 3-node replica set** for AppDB (single-node not supported in 8.0)
- **One MongoDB cluster per Ops Manager project** - use separate projects for multiple deployments

## Quick Start

### Initial Setup

```bash
# 1. Create the Ops Manager VM (x86_64 Ubuntu 22.04)
./scripts/01-create-opsmanager-vm.sh

# 2. Install MongoDB 8.0 as AppDB (3-node replica set)
./scripts/02-install-appdb.sh

# 3. Install Ops Manager 8.0
./scripts/03-install-opsmanager.sh

# 4. Open http://opsmanager.orb.local:8080
#    - Register admin account
#    - Create Organization (e.g., "myorg")
#    - Create Projects: "lab-01" (standalone) and "lab-02" (replica sets)
#    - Generate API Key (Organization → Access Manager → API Keys)
#    - Add IP access list: 192.168.139.0/24

# 5. Configure credentials
cp .env.example .env
# Edit .env with your Ops Manager credentials

# 6. Deploy Kubernetes Operator
./scripts/04-setup-k8s-operator.sh

# 7. Deploy MongoDB clusters using Kustomize
kubectl apply -k k8s/overlays/lab-01    # Standalone
kubectl apply -k k8s/overlays/lab-02    # ReplicaSet
```

### Lifecycle Management

```bash
# Stop everything (preserves all data)
./scripts/stop-all.sh

# Start everything back up
./scripts/start-all.sh

# Destroy everything (ALL DATA LOST)
./scripts/teardown.sh
```

## Configuration

### Environment File (.env)

The `.env` file stores Ops Manager API credentials used by all automation scripts. Create it from the template:

```bash
cp .env.example .env
```

**Required variables:**

| Variable | Description | Example |
|----------|-------------|---------|
| `OPS_MANAGER_URL` | Ops Manager base URL | `http://opsmanager.orb.local:8080` |
| `OPS_MANAGER_ORG_ID` | Organization ID (24-char hex) | `69a34148d21fd11d35c6554c` |
| `OPS_MANAGER_API_PUBLIC_KEY` | API public key | `sbzajcxz` |
| `OPS_MANAGER_API_PRIVATE_KEY` | API private key (UUID format) | `6a04c1e6-89a4-41f9-ba9a-b5152da6323a` |

**How to find these values:**

1. **Org ID**: Organization Settings → Organization ID
2. **API Keys**: Organization → Access Manager → API Keys → Create API Key
   - Assign "Organization Owner" role
   - Add IP access list entry: `192.168.139.0/24`

### Example .env file

```bash
OPS_MANAGER_URL=http://opsmanager.orb.local:8080
OPS_MANAGER_ORG_ID=69a34148d21fd11d35c6554c
OPS_MANAGER_API_PUBLIC_KEY=sbzajcxz
OPS_MANAGER_API_PRIVATE_KEY=6a04c1e6-89a4-41f9-ba9a-b5152da6323a
```

## Ops Manager Automation Scripts

These scripts automate Ops Manager organization and project management via the REST API.

### create-org.sh - Create Organization

Creates a new organization in Ops Manager. Reads API credentials from `.env`.

```bash
# Create an organization named "production"
./scripts/create-org.sh production

# Or run interactively (prompts for name)
./scripts/create-org.sh
```

**Output:**
```
Creating organization 'production' in Ops Manager...

Organization created successfully!
  Name: production
  ID:   69b45259e32ge22f46d7665d

Update your .env file:
  OPS_MANAGER_ORG_ID=69b45259e32ge22f46d7665d

Next steps:
  1. Create an API key for this org in Ops Manager UI
  2. Add IP access list: 192.168.139.0/24
  3. Update .env with the new API key credentials
  4. Run ./scripts/create-project.sh to create projects
```

### create-project.sh - Create Project

Creates a new project within an existing organization. Each project can contain one MongoDB deployment.

```bash
# Create a project named "lab-03"
./scripts/create-project.sh lab-03

# Or run interactively
./scripts/create-project.sh
```

**Output:**
```
Creating project 'lab-03' in organization '69a34148d21fd11d35c6554c'...

Project created successfully!
  Name: lab-03
  ID:   69c56370f43hf33g57e8776e

To use this project with Kustomize:
  1. Create a new overlay directory: k8s/overlays/lab-03/
  2. Copy an existing overlay as a template
  3. Update the projectName in the overlay's patches
```

## Kustomize Deployment

This project uses Kustomize for templated MongoDB deployments. The base template defaults to a Standalone deployment, and overlays customize it for each Ops Manager project.

### Why Kustomize?

- **DRY principle**: Base templates define common configuration once
- **Per-project customization**: Overlays patch only what differs (type, resources, ports)
- **No external tools**: Built into kubectl (`kubectl apply -k`)
- **GitOps friendly**: All configuration is declarative YAML

### How It Works

```
k8s/base/                    # Shared templates
    └── mongodb.yaml         # Standalone by default (type, version, auth, resources)
    └── service.yaml         # NodePort service template
    └── users.yaml           # 3 database users

k8s/overlays/lab-01/         # Patches for lab-01 project
    └── kustomization.yaml   # Changes: name=demo-standalone, nodePort=31261

k8s/overlays/lab-02/         # Patches for lab-02 project
    └── kustomization.yaml   # Changes: type=ReplicaSet, members=3, nodePort=30191
```

### Deploy Using Overlays

```bash
# Preview what will be deployed (dry-run)
kubectl kustomize k8s/overlays/lab-01

# Deploy standalone (lab-01 project)
kubectl apply -k k8s/overlays/lab-01

# Deploy replica set (lab-02 project)
kubectl apply -k k8s/overlays/lab-02

# Delete a deployment
kubectl delete -k k8s/overlays/lab-01
```

### new-overlay.sh - Generate Overlay

Generates a new Kustomize overlay with customizable parameters. The script reads the Org ID from `.env` and auto-assigns an available NodePort.

```bash
# Basic usage - creates Standalone deployment
./scripts/new-overlay.sh lab-03

# Create a 3-node ReplicaSet
./scripts/new-overlay.sh lab-04 --type ReplicaSet

# Create a 5-node ReplicaSet with custom resources
./scripts/new-overlay.sh lab-05 --type ReplicaSet --members 5 --cpu-limit 4 --memory-limit 8Gi

# Specify a custom NodePort
./scripts/new-overlay.sh lab-06 --nodeport 31500

# Override Org ID (useful for multiple orgs)
./scripts/new-overlay.sh lab-07 --org-id 69b45259e32ge22f46d7665d
```

**Output:**
```
Creating Kustomize overlay for 'lab-03'...
  Type:      Standalone
  Members:   1
  NodePort:  31002
  CPU:       2
  Memory:    4Gi
  Org ID:    69a34148d21fd11d35c6554c

Overlay created at: k8s/overlays/lab-03

To preview the generated resources:
  kubectl kustomize k8s/overlays/lab-03

To deploy:
  kubectl apply -k k8s/overlays/lab-03

NOTE: Make sure project 'lab-03' exists in Ops Manager first:
  ./scripts/create-project.sh lab-03
```

### Overlay Options

| Option | Default | Description |
|--------|---------|-------------|
| `--type` | `Standalone` | MongoDB deployment type (`Standalone` or `ReplicaSet`) |
| `--members` | 1 (Standalone), 3 (ReplicaSet) | Number of replica set members |
| `--nodeport` | Auto-assign (31000+) | NodePort for external access from macOS |
| `--cpu-limit` | `2` | CPU limit per pod (cores) |
| `--memory-limit` | `4Gi` | Memory limit per pod |
| `--org-id` | From `.env` | Ops Manager Organization ID |

### Complete Workflow: New Deployment

Here's the full workflow to create a new MongoDB deployment:

```bash
# 1. Create the project in Ops Manager
./scripts/create-project.sh myapp-db

# 2. Generate the Kustomize overlay
./scripts/new-overlay.sh myapp-db --type ReplicaSet --members 3

# 3. Preview the generated resources
kubectl kustomize k8s/overlays/myapp-db

# 4. Deploy to Kubernetes
kubectl apply -k k8s/overlays/myapp-db

# 5. Watch the deployment progress
kubectl get mongodb,pods -n mongodb -w

# 6. Get the connection string
kubectl get svc myapp-db-external -n mongodb
# Connect: mongosh 'mongodb://dbUser:MongoDBPass123!@192.168.139.2:<nodeport>/admin'
```

### Manual Overlay Customization

Each overlay's `kustomization.yaml` uses JSON patches to modify base resources. You can edit these directly:

```yaml
# k8s/overlays/lab-03/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: mongodb
resources:
  - ../../base

patches:
  # Change deployment name and type
  - target:
      kind: MongoDB
      name: mongodb-deployment
    patch: |-
      - op: replace
        path: /metadata/name
        value: my-custom-db
      - op: replace
        path: /spec/type
        value: ReplicaSet
      - op: replace
        path: /spec/members
        value: 5
      # Custom CPU/memory
      - op: replace
        path: /spec/podSpec/podTemplate/spec/containers/0/resources/limits/cpu
        value: "4"
      - op: replace
        path: /spec/podSpec/podTemplate/spec/containers/0/resources/limits/memory
        value: 8Gi
```

### Kustomize Structure

```
k8s/
├── base/                       # Base templates (Standalone default)
│   ├── kustomization.yaml      # Lists all base resources
│   ├── namespace.yaml          # mongodb namespace
│   ├── mongodb.yaml            # MongoDB CRD (Standalone, 8.0, SCRAM auth)
│   ├── service.yaml            # NodePort service template
│   ├── ops-manager-config.yaml # Ops Manager connection ConfigMap
│   ├── ops-manager-secret.yaml # API credentials Secret (placeholder)
│   ├── users.yaml              # 3 MongoDBUser resources
│   └── users-secret.yaml       # User password Secret
└── overlays/                   # Per-project customizations
    ├── lab-01/                 # Standalone deployment
    │   └── kustomization.yaml  # Patches: name, projectName, nodePort
    └── lab-02/                 # ReplicaSet deployment
        └── kustomization.yaml  # Patches: type=ReplicaSet, members=3
```

## Connecting to MongoDB

### From macOS Host

| Deployment | Connection String |
|------------|-------------------|
| Standalone | `mongosh 'mongodb://<user>:MongoDBPass123!@192.168.139.2:31261/admin'` |
| ReplicaSet | `mongosh 'mongodb://<user>:MongoDBPass123!@192.168.139.2:30191/admin?replicaSet=demo-rs'` |

**Note:** Use single quotes to avoid zsh interpreting `!` as history expansion.

### Database Users

All deployments include three pre-configured users:

| User | Password | Roles | Purpose |
|------|----------|-------|---------|
| `dbUser` | `MongoDBPass123!` | `readWriteAnyDatabase` | Application user: CRUD, create collections/indexes |
| `dbAdmin` | `MongoDBPass123!` | `dbAdminAnyDatabase`, `userAdminAnyDatabase`, `readWriteAnyDatabase` | DBA: create databases, manage users |
| `sysAdmin` | `MongoDBPass123!` | `root` | Superuser: full control |

### Example Connections

```bash
# Application user (standalone)
mongosh 'mongodb://dbUser:MongoDBPass123!@192.168.139.2:31261/admin'

# Database admin (standalone)
mongosh 'mongodb://dbAdmin:MongoDBPass123!@192.168.139.2:31261/admin'

# Superuser (standalone)
mongosh 'mongodb://sysAdmin:MongoDBPass123!@192.168.139.2:31261/admin'

# Replica set connection
mongosh 'mongodb://dbUser:MongoDBPass123!@192.168.139.2:30191/admin?replicaSet=demo-rs'
```

### Find NodePort for Custom Deployments

```bash
# List all MongoDB services
kubectl get svc -n mongodb

# Get specific deployment's NodePort
kubectl get svc myapp-db-external -n mongodb -o jsonpath='{.spec.ports[0].nodePort}'
```

## Resource Allocation

### K8s MongoDB Deployments (Default)

| Deployment | CPU (req/limit) | RAM (req/limit) | Disk | Nodes |
|------------|-----------------|-----------------|------|-------|
| Standalone | 1 / 2 cores | 2Gi / 4Gi | 16GB | 1 |
| ReplicaSet (per node) | 1 / 2 cores | 2Gi / 4Gi | 16GB | 3 |
| ReplicaSet (total) | 3 / 6 cores | 6Gi / 12Gi | 48GB | 3 |

### Ops Manager VM

| Component | Resources |
|-----------|-----------|
| AppDB (3-node RS) | Ports 27017, 27018, 27019 |
| Ops Manager | Port 8080, ~8GB heap |

## Project Structure

```
mongodb-pro/
├── README.md
├── .env                          # Ops Manager credentials (git-ignored)
├── .env.example                  # Template for .env
├── scripts/
│   ├── 01-create-opsmanager-vm.sh   # Create x86_64 Ubuntu VM
│   ├── 02-install-appdb.sh          # Install MongoDB 8.0 AppDB (3-node RS)
│   ├── 03-install-opsmanager.sh     # Install Ops Manager 8.0
│   ├── 04-setup-k8s-operator.sh     # Deploy K8s Operator + secrets
│   ├── create-org.sh               # Create Ops Manager organization (API)
│   ├── create-project.sh           # Create Ops Manager project (API)
│   ├── new-overlay.sh              # Generate Kustomize overlay
│   ├── start-all.sh                # Start VM + scale up K8s workloads
│   ├── stop-all.sh                 # Scale down K8s + stop VM
│   └── teardown.sh                 # Destroy everything
├── config/
│   └── mongod.conf                  # AppDB config reference
├── k8s/
│   ├── base/                        # Kustomize base templates
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── mongodb.yaml
│   │   ├── service.yaml
│   │   ├── ops-manager-config.yaml
│   │   ├── ops-manager-secret.yaml
│   │   ├── users.yaml
│   │   └── users-secret.yaml
│   ├── overlays/                    # Per-project overlays
│   │   ├── lab-01/                  # Standalone deployment
│   │   └── lab-02/                  # ReplicaSet deployment
│   ├── mongodb-standalone.yaml      # Legacy: standalone (lab-01)
│   ├── mongodb-replicaset.yaml      # Legacy: replica set (lab-02)
│   ├── mongodb-services.yaml        # Legacy: NodePort services
│   ├── mongodb-users-secret.yaml    # Legacy: user credentials
│   └── mongodb-users.yaml           # Legacy: MongoDBUser resources
└── docs/
    └── NOTES.md
```

## How Stop/Start Works

### stop-all.sh

1. **Scales down K8s StatefulSets** to 0 replicas
   - Pods terminate gracefully
   - PersistentVolumeClaims (PVCs) are preserved
   - Data remains intact on disk
2. **Stops the Ops Manager VM**
   - AppDB and Ops Manager shut down
   - VM disk state is preserved
3. **Operator keeps running** (lightweight, ready for restart)

### start-all.sh

1. **Starts the Ops Manager VM**
2. **Waits for AppDB** (MongoDB 3-node RS on ports 27017-27019)
3. **Waits for Ops Manager** (HTTP 200/302/303 on port 8080)
4. **Scales up K8s StatefulSets**
   - Pods reattach to existing PVCs
   - Data is restored automatically
5. **Waits for MongoDB pods** to be ready

### Data Persistence

| Component | Storage | Survives Stop/Start | Survives Teardown |
|-----------|---------|---------------------|-------------------|
| AppDB | VM disk `/var/lib/mongodb/` | Yes | No |
| Ops Manager | VM disk `/opt/mongodb/mms/` | Yes | No |
| K8s MongoDB | PersistentVolumeClaims | Yes | No |

## Ops Manager Projects

| Project | Purpose | Kustomize Overlay | Deployments |
|---------|---------|-------------------|-------------|
| lab-01 | Standalone instances | `k8s/overlays/lab-01` | demo-standalone |
| lab-02 | Replica sets | `k8s/overlays/lab-02` | demo-rs |

## Troubleshooting

### Check VM Status
```bash
orb list
orb -m opsmanager -u root systemctl status mongod-rs1 mongod-rs2 mongod-rs3
orb -m opsmanager -u root systemctl status mongodb-mms
```

### Check K8s Status
```bash
kubectl get mongodb,pods -n mongodb
kubectl describe mongodb demo-standalone -n mongodb
kubectl logs deployment/mongodb-enterprise-operator -n mongodb
```

### Check Services/Endpoints
```bash
kubectl get svc,endpoints -n mongodb
```

### View Ops Manager Logs
```bash
orb -m opsmanager -u root tail -f /opt/mongodb/mms/logs/mms0.log
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Connection refused after restart | Reapply overlay: `kubectl apply -k k8s/overlays/lab-01` |
| "Too many open files" | File limits configured in install scripts |
| "at least 3 nodes required" | AppDB must be 3-node RS (handled by scripts) |
| "IP address not on access list" | Add `192.168.139.0/24` to API key access list in Ops Manager |
| "organization not found" | Verify Org ID in .env matches Ops Manager |
| zsh `event not found` error | Use single quotes for connection strings with `!` |
| create-org.sh fails with 401 | API credentials invalid; regenerate in Ops Manager UI |
| create-project.sh fails with 404 | Org ID in .env doesn't exist; verify or run create-org.sh |
| Overlay already exists | Delete directory: `rm -rf k8s/overlays/<name>` |

## Resources

- [MongoDB Ops Manager Documentation](https://www.mongodb.com/docs/ops-manager/current/)
- [MongoDB Enterprise Kubernetes Operator](https://www.mongodb.com/docs/kubernetes-operator/stable/)
- [OrbStack Documentation](https://docs.orbstack.dev/)
- [Kustomize Documentation](https://kustomize.io/)
