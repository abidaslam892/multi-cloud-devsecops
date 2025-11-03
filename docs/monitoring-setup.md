# Monitoring Stack Setup Guide

This guide walks through setting up the complete monitoring stack (Prometheus, Grafana, Loki) on your Kubernetes cluster.

## Prerequisites

### 1. Install kubectl

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**macOS:**
```bash
brew install kubectl
```

**Windows (Chocolatey):**
```powershell
choco install kubernetes-cli
```

### 2. Install Helm

**Linux (using script):**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Ubuntu/Debian:**
```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

**macOS:**
```bash
brew install helm
```

**Windows (Chocolatey):**
```powershell
choco install kubernetes-helm
```

**Verify installation:**
```bash
helm version
```

## Quick Installation

### Option 1: Automated Installation (Recommended)

```bash
# Run the installation script
./monitoring/install-monitoring.sh prod
```

This will:
- Create the `monitoring` namespace
- Add required Helm repositories
- Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
- Install Loki for log aggregation
- Apply custom alert rules
- Load Grafana dashboards

### Option 2: Manual Installation

#### Step 1: Create Namespace
```bash
kubectl create namespace monitoring
```

#### Step 2: Add Helm Repositories
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

#### Step 3: Install Prometheus Stack
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values.yaml \
  --create-namespace
```

#### Step 4: Install Loki
```bash
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --values monitoring/loki-values.yaml
```

#### Step 5: Apply Custom Alerts
```bash
kubectl apply -f monitoring/prometheus/alerts.yaml -n monitoring
```

#### Step 6: Load Grafana Dashboards
```bash
kubectl create configmap grafana-app-dashboards \
  --from-file=monitoring/grafana/dashboards/ \
  --namespace monitoring
```

## Accessing the Monitoring Stack

### Grafana (Default)
```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at: http://localhost:3000
# Default credentials: admin / changeme
```

### Prometheus
```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access at: http://localhost:9090
```

### Alertmanager
```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Access at: http://localhost:9093
```

### Loki
```bash
# Port forward
kubectl port-forward -n monitoring svc/loki 3100:3100

# Access at: http://localhost:3100
```

## Configuration Updates

### Update Grafana Admin Password

Edit `monitoring/prometheus-values.yaml` or `monitoring/grafana-values.yaml`:
```yaml
grafana:
  adminPassword: "your-secure-password"
```

Then upgrade:
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/prometheus-values.yaml
```

### Configure Alertmanager Notifications

Edit `monitoring/prometheus-values.yaml` and configure receivers:

**Slack:**
```yaml
alertmanager:
  config:
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
            channel: '#alerts'
            title: '{{ .CommonAnnotations.summary }}'
```

**Email:**
```yaml
alertmanager:
  config:
    receivers:
      - name: 'email'
        email_configs:
          - to: 'ops-team@example.com'
            from: 'alertmanager@example.com'
            smarthost: 'smtp.gmail.com:587'
            auth_username: 'your-email@gmail.com'
            auth_password: 'your-app-password'
```

Apply changes:
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/prometheus-values.yaml
```

## Adding Custom Dashboards

1. Export dashboard JSON from Grafana UI
2. Save to `monitoring/grafana/dashboards/`
3. Update ConfigMap:
```bash
kubectl create configmap grafana-app-dashboards \
  --from-file=monitoring/grafana/dashboards/ \
  --namespace monitoring \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Troubleshooting

### Context Deadline Exceeded (Helm Timeout)

If you encounter "UPGRADE FAILED: context deadline exceeded", try these solutions:

**1. Increase Helm timeout:**
```bash
# For installation (default: 5 minutes)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values.yaml \
  --timeout 10m \
  --wait

# For upgrades
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/prometheus-values.yaml \
  --timeout 10m \
  --wait
```

**2. Install without waiting for readiness:**
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values.yaml \
  --timeout 10m \
  --wait=false
```

**3. Check cluster resources:**
```bash
# Check if nodes have sufficient resources
kubectl top nodes

# Check pending pods
kubectl get pods -n monitoring

# Describe stuck pods
kubectl describe pod -n monitoring <pod-name>
```

**4. Install components separately:**
```bash
# Install Prometheus Operator first
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.enabled=false \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --timeout 10m

# Then enable components incrementally
helm upgrade prometheus-operator prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --reuse-values \
  --set prometheus.enabled=true \
  --timeout 10m
```

**5. Check for existing releases:**
```bash
# List all releases
helm list -n monitoring

# If stuck in pending-install or pending-upgrade state, rollback
helm rollback prometheus -n monitoring

# Or uninstall and reinstall
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

**6. Reduce resource requirements (for development):**

Create a minimal values file `monitoring/prometheus-values-minimal.yaml`:
```yaml
prometheus:
  prometheusSpec:
    retention: 7d
    retentionSize: "10GB"
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    storageSpec: {}  # Use emptyDir instead of PVC

alertmanager:
  enabled: false

grafana:
  enabled: true
  adminPassword: "changeme"
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 250m
      memory: 512Mi
  persistence:
    enabled: false  # Use emptyDir for development

prometheus-node-exporter:
  enabled: true

kube-state-metrics:
  enabled: true
```

Install with minimal resources:
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values-minimal.yaml \
  --create-namespace \
  --timeout 15m
```

### Check Prometheus Targets
```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Visit: http://localhost:9090/targets
```

### Check Grafana Datasources
```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Visit: http://localhost:3000/datasources
```

### View Logs
```bash
# Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Loki logs
kubectl logs -n monitoring -l app=loki
```

### Restart Components
```bash
# Restart Grafana
kubectl rollout restart deployment -n monitoring prometheus-grafana

# Restart Prometheus
kubectl rollout restart statefulset -n monitoring prometheus-kube-prometheus-prometheus
```

## Uninstall

```bash
# Remove all monitoring components
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring

# Delete namespace
kubectl delete namespace monitoring
```

## Production Considerations

1. **Storage**: Update `storageClassName` in values files for your cloud provider
2. **Ingress**: Configure proper domain names and TLS certificates
3. **Credentials**: Use strong passwords and store in secrets
4. **Retention**: Adjust based on storage capacity and compliance requirements
5. **Alerting**: Configure proper notification channels (Slack, PagerDuty, email)
6. **Backups**: Set up regular backups of Grafana dashboards and Prometheus data
7. **Resource Limits**: Adjust based on cluster size and metric cardinality
