# mongodb-pro

Local MongoDB Enterprise environment with Ops Manager and Kubernetes Operator on macOS (Apple Silicon).

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  macOS (Apple Silicon M4 Max)                           │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  OrbStack (Apple Virtualization.framework)        │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  VM: opsmanager (Ubuntu 22.04, x86_64)      │  │  │
│  │  │  - MongoDB 8.0 (AppDB, single-node RS)      │  │  │
│  │  │  - Ops Manager 8.0                          │  │  │
│  │  │  - Accessible at:                           │  │  │
|  |  |  - http://opsmanager.orb.local:8080         │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Kubernetes (OrbStack built-in K8s)         │  │  │
│  │  │  - MongoDB Enterprise Kubernetes Operator   │  │  │
│  │  │  - MongoDB standalone & replica sets        │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

- macOS 15+ on Apple Silicon
- OrbStack installed (personal edition is fine)
- Rosetta enabled in OrbStack settings
- OrbStack memory limit raised to at least 12 GB (Settings → System → Memory)
- `kubectl` available (OrbStack bundles it)

## Key Constraint

**Ops Manager is x86_64 only.** The VM runs under OrbStack's Rosetta translation layer.
MongoDB Server itself has arm64 builds, but since the AppDB lives inside the same
x86_64 VM as Ops Manager, it also runs as x86_64.

## Usage

```bash
# Step 1: Create and provision the Ops Manager VM
./scripts/01-create-opsmanager-vm.sh

# Step 2: Install MongoDB AppDB in the VM
./scripts/02-install-appdb.sh

# Step 3: Install Ops Manager in the VM
./scripts/03-install-opsmanager.sh

# Lifecycle
./scripts/stop-all.sh      # Stop everything, preserve state
./scripts/start-all.sh     # Start everything back up
./scripts/teardown.sh      # Destroy everything
```

## Project Structure

```
mongodb-pro/
├── README.md
├── scripts/
│   ├── 01-create-opsmanager-vm.sh   # Create the x86_64 Ubuntu VM
│   ├── 02-install-appdb.sh          # Install MongoDB as AppDB
│   ├── 03-install-opsmanager.sh     # Install Ops Manager 8.0
│   ├── stop-all.sh                  # Stop VM + K8s workloads
│   ├── start-all.sh                 # Restart everything
│   └── teardown.sh                  # Destroy everything
├── config/
│   └── mongod.conf                  # AppDB mongod configuration
└── docs/
    └── notes.md                     # Working notes & decisions
```