Run the teardown script:

```bash
./scripts/teardown.sh
```

It will:
- Delete all K8s MongoDB deployments and PVCs
- Delete all mongodb-* namespaces
- Delete the opsmanager VM
- Clean up demo-*/dev-* overlay directories

Type `yes` when prompted.

Then rebuild from scratch:

```bash
./scripts/01-create-opsmanager-vm.sh
./scripts/02-install-appdb.sh
./scripts/03-install-opsmanager.sh
./scripts/03a-configure-tls.sh  # Optional: Enable HTTPS
# Create new API key in Ops Manager UI (add 192.168.139.0/24 to access list)
# Update .env with new credentials (use https:// URL if TLS enabled)
./scripts/04-setup-k8s-operator.sh
```

Then deploy:

```bash
./scripts/new-overlay.sh demo-standalone
kubectl apply -k k8s/overlays/demo-standalone
kubectl get mongodb -n mongodb-demo-standalone -w
```

Once Running, load data and query:

```bash
./scripts/load-sample-data.sh demo-standalone
./scripts/query-sample-data.sh demo-standalone
```
