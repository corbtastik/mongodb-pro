# MongoDB Enterprise Automation Demo

**Duration:** 30 minutes
**Focus:** Automation and Operational Excellence with MongoDB Ops Manager

## Key Message

MongoDB Ops Manager provides a **unified control plane** for MongoDB Enterprise databases with full API-driven automation. Every operation—from project creation to cluster deployment to scaling—can be automated, enabling GitOps workflows, infrastructure-as-code, and operational excellence at scale.

---

## Demo Flow

| Section | Duration | Focus |
|---------|----------|-------|
| 1. Context & Architecture | 3 min | Why automation matters |
| 2. Ops Manager Tour | 5 min | The control plane |
| 3. API-Driven Project Setup | 7 min | Automated project creation |
| 4. Declarative Deployment | 10 min | Deploy MongoDB clusters |
| 5. Operational Excellence | 5 min | Day-2 operations |

---

## Pre-Demo Checklist

Run these commands before the demo to ensure everything is ready:

```bash
# Verify Ops Manager is running
curl -s -o /dev/null -w "%{http_code}" http://opsmanager.orb.local:8080
# Expected: 200, 302, or 303

# Verify K8s operator is running
kubectl get pods -n mongodb | grep operator
# Expected: mongodb-enterprise-operator running

# Verify .env is configured
cat .env | grep -v "^#" | grep -v "^$"
# Expected: All 4 variables set

# Verify API access works
./scripts/create-project.sh pre-demo-test
# Expected: Project created successfully
# Clean up: delete "pre-demo-test" project in Ops Manager UI
```

---

## 1. Context & Architecture (3 min)

### Talking Points

> "In enterprise environments, managing MongoDB at scale requires more than manual administration. You need **automation**, **consistency**, and **operational visibility**."

> "MongoDB Ops Manager is our enterprise control plane. It provides a single pane of glass for all MongoDB deployments, and critically, it exposes a **complete REST API** that enables full automation."

> "Today I'll show you how MongoDB management—from project setup to cluster deployment—can be fully automated. Infrastructure as code, GitOps workflows, CI/CD integration."

### Show Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AUTOMATION LAYER                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Scripts/CLI │  │  CI/CD      │  │ Infrastructure as   │  │
│  │             │  │  Pipelines  │  │ Code (Terraform,    │  │
│  │             │  │             │  │ Kustomize, etc.)    │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┼─────────────────────┘             │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              MONGODB OPS MANAGER                       │  │
│  │                   REST API                             │  │
│  │  • Projects         • Monitoring    • Backup           │  │
│  │  • Deployments      • Alerts        • Automation       │  │
│  │  • Users/Roles      • Metrics       • Security         │  │
│  └───────────────────────────────────────────────────────┘  │
│                          │                                   │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              MONGODB DEPLOYMENTS                       │  │
│  │     Standalone    ReplicaSets    Sharded Clusters     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Ops Manager Tour (5 min)

### Open Ops Manager UI

```
http://opsmanager.orb.local:8080
```

### Key Points to Highlight

1. **Organizations** - Logical grouping for teams/business units
   - Navigate to: Organization Settings
   - Show: Organization ID (this is what the API uses)
   - Note: "Organizations are typically set up once by admins. Projects within them are what teams automate."

2. **Projects** - Isolation boundary for deployments
   - Each project = one MongoDB deployment
   - Separate monitoring, alerts, backups
   - "This is where automation shines—project creation, deployment, configuration."

3. **Access Manager** - API Keys
   - Navigate to: Organization → Access Manager → API Keys
   - Show: Public/Private key pairs
   - Emphasize: "This is how automation authenticates—no user passwords in scripts."

4. **Deployment View** (if clusters exist)
   - Real-time topology
   - Health monitoring
   - Configuration management

### Key Quote

> "Everything you see in this UI is backed by a REST API. Any action you can perform here, you can automate."

---

## 3. API-Driven Project Setup (7 min)

### Show the Credentials File

```bash
cat .env
```

> "Our automation scripts read credentials from this environment file. No hardcoded secrets, easy to integrate with secret management systems like Vault or AWS Secrets Manager."

### Explain the Automation Model

> "In Ops Manager, **Organizations** are your top-level structure—typically one per business unit or team. Within each organization, **Projects** contain your MongoDB deployments. Organizations are set up once, but projects are created frequently—one for each application, environment, or use case."

> "Let's create projects for two different deployment types."

### Create Projects via API

```bash
# Show the script
head -40 scripts/create-project.sh

# Create a project for a standalone deployment
./scripts/create-project.sh demo-standalone
```

**Expected Output:**
```
Creating project 'demo-standalone' in organization '69a34148d21fd11d35c6554c'...

Project created successfully!
  Name: demo-standalone
  ID:   69c56370f43hf33g57e8776e
```

```bash
# Create a project for a replica set
./scripts/create-project.sh demo-replicaset
```

> "Two projects created in seconds via API. In a real environment, this could be triggered by a Jira ticket, a Terraform apply, or a self-service portal."

### Verify in UI

Switch to Ops Manager UI and show the new projects.

> "The API and UI are always in sync. Operations teams can use the UI for visibility while automation handles provisioning."

---

## 4. Declarative Deployment (10 min)

### Explain the Approach

> "Now we'll deploy MongoDB clusters. We're using a declarative approach—we describe the **desired state**, and the system makes it happen. This is the same pattern as Kubernetes, Terraform, and modern infrastructure tools."

### Generate Deployment Configurations

```bash
# Generate configuration for a standalone instance
./scripts/new-overlay.sh demo-standalone

# Generate configuration for a 3-node replica set
./scripts/new-overlay.sh demo-replicaset --type ReplicaSet --members 3
```

### Show What Was Generated

```bash
# Preview the standalone configuration
kubectl kustomize k8s/overlays/demo-standalone
```

> "This YAML describes our desired state: MongoDB 8.0 Enterprise, SCRAM authentication, specific resource allocation. It's version-controlled, reviewable, and repeatable."

### Deploy the Clusters

```bash
# Deploy standalone
kubectl apply -k k8s/overlays/demo-standalone

# Deploy replica set
kubectl apply -k k8s/overlays/demo-replicaset
```

### Watch Deployment Progress

```bash
# Watch pods come up
kubectl get pods -n mongodb -w
```

> "The MongoDB Enterprise Operator reads our configuration, communicates with Ops Manager, and provisions the databases. Ops Manager handles the actual MongoDB deployment, configuration, and agent installation."

### Show in Ops Manager UI

Navigate to the projects in Ops Manager and show:

1. **Deployment topology** - Nodes appearing in real-time
2. **Automation status** - Goal state vs current state
3. **Monitoring** - Metrics automatically flowing

> "Ops Manager is now managing these databases. It handles configuration, monitors health, and can perform automated operations like rolling restarts and upgrades."

### Connect to the Database

```bash
# Get the connection ports
kubectl get svc -n mongodb | grep demo

# Connect to standalone (adjust port from svc output)
mongosh 'mongodb://dbUser:MongoDBPass123!@192.168.139.2:<nodeport>/admin'

# Quick test
db.demo.insertOne({message: "Hello from automation", timestamp: new Date()})
db.demo.find()
```

---

## 5. Operational Excellence (5 min)

### Day-2 Operations

> "Deployment is just the beginning. Let's talk about ongoing operations."

#### Scaling (Declarative)

```bash
# Show the overlay configuration
cat k8s/overlays/demo-replicaset/kustomization.yaml
```

> "To scale from 3 to 5 nodes, we change one number in our configuration and reapply. Ops Manager handles the rolling addition of new members—no manual replica set reconfiguration."

#### Monitoring & Alerts

Show in Ops Manager UI:
- Real-time metrics (connections, operations, replication lag)
- Alert configurations
- Integration options (PagerDuty, Slack, email)

> "Ops Manager provides enterprise monitoring out of the box. No need to set up separate Prometheus, Grafana, or alerting infrastructure."

#### Backup & Recovery

Navigate to Backup section (if configured):
- Continuous backup
- Point-in-time recovery
- Snapshot management

> "Enterprise backup is built in. You can restore to any point in time within your retention window."

### The Automation Story

> "Let's recap what we automated today:"

| Operation | Method | Time |
|-----------|--------|------|
| Create Projects | API Script | 2 seconds each |
| Generate Configs | CLI Script | 1 second each |
| Deploy Clusters | Declarative Apply | ~3 minutes |
| **Total** | | **< 5 minutes** |

> "What traditionally takes hours of manual work—provisioning infrastructure, installing MongoDB, configuring replica sets, setting up monitoring—is now a few commands and a few minutes."

---

## Wrap-Up Talking Points

1. **Full API Coverage** - Ops Manager operations are API-accessible
2. **Declarative Management** - Describe desired state, system handles convergence
3. **GitOps Ready** - Configurations are YAML, versionable, reviewable
4. **Unified Control Plane** - Single view across all MongoDB deployments
5. **Enterprise Features Built-In** - Monitoring, backup, security, automation

---

## Q&A Prompts

Be prepared to discuss:

- **"How does this integrate with Terraform?"** - MongoDB has a Terraform provider that wraps the Ops Manager API
- **"What about cloud deployments?"** - Same patterns work with MongoDB Atlas (cloud) via its API
- **"How do you handle secrets?"** - .env files for demos; production uses Vault, AWS Secrets Manager, K8s secrets
- **"What about upgrades?"** - Ops Manager handles rolling upgrades; change version in config, reapply
- **"Multi-region?"** - Ops Manager can manage deployments across regions/data centers
- **"Can you automate organization creation?"** - Organizations require user authentication (admin setup); projects and below are fully API-automatable with API keys

---

## Emergency Recovery Commands

If something goes wrong during the demo:

```bash
# Check operator logs
kubectl logs deployment/mongodb-enterprise-operator -n mongodb --tail=50

# Check MongoDB resource status
kubectl describe mongodb demo-standalone -n mongodb

# Restart operator if stuck
kubectl rollout restart deployment/mongodb-enterprise-operator -n mongodb

# Nuclear option: delete and redeploy
kubectl delete -k k8s/overlays/demo-standalone
kubectl apply -k k8s/overlays/demo-standalone
```

---

## Post-Demo Cleanup

```bash
# Delete demo deployments
kubectl delete -k k8s/overlays/demo-standalone
kubectl delete -k k8s/overlays/demo-replicaset

# Remove overlay directories
rm -rf k8s/overlays/demo-standalone k8s/overlays/demo-replicaset

# Projects remain in Ops Manager (delete via UI if needed)
```
