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

# 6. Deploy Kubernetes Operator and MongoDB clusters
./scripts/04-setup-k8s-operator.sh
kubectl apply -f k8s/mongodb-standalone.yaml
kubectl apply -f k8s/mongodb-replicaset.yaml
kubectl apply -f k8s/mongodb-services.yaml
kubectl apply -f k8s/mongodb-users-secret.yaml
kubectl apply -f k8s/mongodb-users.yaml
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

## Connecting to MongoDB

### From macOS Host

| Deployment | Connection String |
|------------|-------------------|
| Standalone | `mongosh 'mongodb://<user>:MongoDBPass123!@192.168.139.2:31261/admin'` |
| ReplicaSet | `mongosh 'mongodb://<user>:MongoDBPass123!@192.168.139.2:30191/admin?replicaSet=demo-rs'` |

**Note:** Use single quotes to avoid zsh interpreting `!` as history expansion.

### Database Users

| User | Password | Roles | Purpose |
|------|----------|-------|---------|
| `dbUser` | `MongoDBPass123!` | `readWriteAnyDatabase` | Application user: CRUD, create collections/indexes |
| `dbAdmin` | `MongoDBPass123!` | `dbAdminAnyDatabase`, `userAdminAnyDatabase`, `readWriteAnyDatabase` | DBA: create databases, manage users |
| `sysAdmin` | `MongoDBPass123!` | `root` | Superuser: full control |

### Example Connections

```bash
# Application user
mongosh 'mongodb://dbUser:MongoDBPass123!@192.168.139.2:31261/admin'

# Database admin
mongosh 'mongodb://dbAdmin:MongoDBPass123!@192.168.139.2:31261/admin'

# Superuser
mongosh 'mongodb://sysAdmin:MongoDBPass123!@192.168.139.2:31261/admin'

# Replica set connection
mongosh 'mongodb://dbUser:MongoDBPass123!@192.168.139.2:30191/admin?replicaSet=demo-rs'
```

## Resource Allocation

### K8s MongoDB Deployments

| Deployment | CPU (req/limit) | RAM (req/limit) | Disk | Nodes |
|------------|-----------------|-----------------|------|-------|
| demo-standalone | 1 / 2 cores | 2Gi / 4Gi | 16GB | 1 |
| demo-rs (per node) | 1 / 2 cores | 2Gi / 4Gi | 16GB | 3 |
| demo-rs (total) | 3 / 6 cores | 6Gi / 12Gi | 48GB | 3 |

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
│   ├── 04-setup-k8s-operator.sh     # Deploy K8s Operator + ConfigMaps
│   ├── start-all.sh                 # Start VM + scale up K8s workloads
│   ├── stop-all.sh                  # Scale down K8s + stop VM
│   └── teardown.sh                  # Destroy everything
├── config/
│   └── mongod.conf                  # AppDB config reference
├── k8s/
│   ├── namespace.yaml               # mongodb namespace
│   ├── ops-manager-config.yaml      # Ops Manager connection (lab-01)
│   ├── ops-manager-config-lab02.yaml # Ops Manager connection (lab-02)
│   ├── ops-manager-secret.yaml      # API credentials
│   ├── mongodb-standalone.yaml      # Standalone deployment (lab-01)
│   ├── mongodb-replicaset.yaml      # 3-node ReplicaSet (lab-02)
│   ├── mongodb-services.yaml        # NodePort services for external access
│   ├── mongodb-users-secret.yaml    # User credentials (3 users)
│   └── mongodb-users.yaml           # MongoDBUser resources (6 total)
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
| AppDB | VM disk `/var/lib/mongodb/` | ✅ Yes | ❌ No |
| Ops Manager | VM disk `/opt/mongodb/mms/` | ✅ Yes | ❌ No |
| K8s MongoDB | PersistentVolumeClaims | ✅ Yes | ❌ No |

## Ops Manager Projects

| Project | Purpose | K8s ConfigMap | Deployments |
|---------|---------|---------------|-------------|
| lab-01 | Standalone instances | `ops-manager-connection` | demo-standalone |
| lab-02 | Replica sets | `ops-manager-connection-lab02` | demo-rs |

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
| Connection refused after restart | Reapply services: `kubectl apply -f k8s/mongodb-services.yaml` |
| "Too many open files" | File limits configured in install scripts |
| "at least 3 nodes required" | AppDB must be 3-node RS (handled by scripts) |
| "IP address not on access list" | Add `192.168.139.0/24` to API key access list in Ops Manager |
| "organization not found" | Verify Org ID in .env matches Ops Manager |
| zsh `event not found` error | Use single quotes for connection strings with `!` |

## Resources

- [MongoDB Ops Manager Documentation](https://www.mongodb.com/docs/ops-manager/current/)
- [MongoDB Enterprise Kubernetes Operator](https://www.mongodb.com/docs/kubernetes-operator/stable/)
- [OrbStack Documentation](https://docs.orbstack.dev/)
