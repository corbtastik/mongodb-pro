# mongodb-pro

Local MongoDB Enterprise environment with Ops Manager and Kubernetes Operator on macOS (Apple Silicon). Demonstrates API-driven automation and operational excellence with MongoDB Ops Manager.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  macOS (Apple Silicon)                                      │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  OrbStack                                             │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  VM: opsmanager (Ubuntu 22.04, x86_64 Rosetta)  │  │  │
│  │  │  - MongoDB 8.0 AppDB (3-node replica set)       │  │  │
│  │  │  - Ops Manager 8.0                              │  │  │
│  │  │  - http://opsmanager.orb.local:8080             │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Kubernetes (OrbStack built-in)                 │  │  │
│  │  │  - MongoDB Enterprise Kubernetes Operator       │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- macOS 15+ on Apple Silicon
- [OrbStack](https://orbstack.dev/) installed
  - Rosetta enabled (Settings → System → Use Rosetta)
  - Memory limit: 16+ GB recommended (Settings → System → Memory)
  - Kubernetes enabled (Settings → Kubernetes → Enable)
- [Homebrew](https://brew.sh/) installed (for Helm)

## Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/corbtastik/mongodb-pro.git
cd mongodb-pro
```

### Step 2: Create the Ops Manager VM

Creates an x86_64 Ubuntu VM using Rosetta emulation (required because Ops Manager is x86_64 only).

```bash
./scripts/01-create-opsmanager-vm.sh
```

### Step 3: Install MongoDB AppDB

Installs MongoDB 8.0 as a 3-node replica set. This serves as the backend database for Ops Manager.

```bash
./scripts/02-install-appdb.sh
```

### Step 4: Install Ops Manager

Downloads and installs Ops Manager 8.0.

```bash
./scripts/03-install-opsmanager.sh
```

### Step 5: Configure Ops Manager (UI)

Open http://opsmanager.orb.local:8080 and complete initial setup:

1. **Register** - Create your admin account (first user becomes admin)
2. **Configure** - Accept defaults or configure SMTP if desired
3. **Create Organization** - e.g., "myorg"
4. **Create API Key**:
   - Go to: Organization → Access Manager → API Keys → Create API Key
   - Description: "automation"
   - Permissions: Organization Owner
   - Copy the Public Key and Private Key
   - Add to Access List: `192.168.139.0/24`

### Step 6: Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your Ops Manager values:

```bash
OPS_MANAGER_URL=http://opsmanager.orb.local:8080
OPS_MANAGER_ORG_ID=<your-24-char-org-id>
OPS_MANAGER_API_PUBLIC_KEY=<your-public-key>
OPS_MANAGER_API_PRIVATE_KEY=<your-private-key>
```

**Where to find these:**
- **Org ID**: Organization → Settings → Organization ID
- **API Keys**: Created in Step 5

### Step 7: Deploy Kubernetes Operator

Installs the MongoDB Enterprise Kubernetes Operator and creates necessary secrets.

```bash
./scripts/04-setup-k8s-operator.sh
```

### Step 8: Verify Setup

```bash
# Ops Manager is accessible
curl -s -o /dev/null -w "%{http_code}\n" http://opsmanager.orb.local:8080

# Operator is running
kubectl get pods -n mongodb

# API credentials work
./scripts/create-project.sh test-project
```

If all commands succeed, you're ready for the demo.

---

## Demo

See **[docs/DEMO.md](docs/DEMO.md)** for a 30-minute walkthrough demonstrating:

- API-driven organization and project creation
- Declarative MongoDB deployment
- Operational excellence with Ops Manager

---

## Daily Operations

### Stop Environment (Preserves Data)

```bash
./scripts/stop-all.sh
```

### Start Environment

```bash
./scripts/start-all.sh
```

---

## Teardown

Destroys everything including all data. Use when you want to start fresh.

```bash
./scripts/teardown.sh
```

To set up again, start from [Step 2](#step-2-create-the-ops-manager-vm).

---

## Troubleshooting

### Ops Manager not accessible

```bash
# Check VM is running
orb list

# Check Ops Manager service
orb -m opsmanager -u root systemctl status mongodb-mms
```

### Operator not starting

```bash
# Check operator logs
kubectl logs deployment/mongodb-enterprise-operator -n mongodb

# Verify secrets exist
kubectl get secrets -n mongodb
```

### API calls failing (401/403)

- Verify `.env` credentials match Ops Manager
- Ensure `192.168.139.0/24` is in API key access list
- Regenerate API key if needed

### MongoDB pods not starting

```bash
# Check MongoDB resource status
kubectl describe mongodb -n mongodb

# Check operator logs for errors
kubectl logs deployment/mongodb-enterprise-operator -n mongodb --tail=100
```

---

## Project Structure

```
mongodb-pro/
├── scripts/
│   ├── 01-create-opsmanager-vm.sh   # Create VM
│   ├── 02-install-appdb.sh          # Install MongoDB AppDB
│   ├── 03-install-opsmanager.sh     # Install Ops Manager
│   ├── 04-setup-k8s-operator.sh     # Deploy K8s Operator
│   ├── create-org.sh               # Create Ops Manager org (API)
│   ├── create-project.sh           # Create Ops Manager project (API)
│   ├── new-overlay.sh              # Generate Kustomize overlay
│   ├── start-all.sh                # Start environment
│   ├── stop-all.sh                 # Stop environment
│   └── teardown.sh                 # Destroy everything
├── k8s/
│   ├── base/                        # Kustomize base templates
│   └── overlays/                    # Per-project configurations
├── docs/
│   └── DEMO.md                      # Demo walkthrough
├── .env.example                     # Environment template
└── README.md
```

---

## Resources

- [MongoDB Ops Manager Documentation](https://www.mongodb.com/docs/ops-manager/current/)
- [MongoDB Enterprise Kubernetes Operator](https://www.mongodb.com/docs/kubernetes-operator/stable/)
- [OrbStack Documentation](https://docs.orbstack.dev/)
