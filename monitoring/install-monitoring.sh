#!/bin/bash
# Install monitoring stack on Kubernetes cluster
#
# Usage:
#   ./monitoring/install-monitoring.sh [ENVIRONMENT] [--minimal]
#
# Arguments:
#   ENVIRONMENT - Target environment (dev, stage, prod) - default: dev
#   --minimal   - Use minimal resource configuration (optional)
#
# Examples:
#   ./monitoring/install-monitoring.sh dev
#   ./monitoring/install-monitoring.sh dev --minimal
#   ./monitoring/install-monitoring.sh prod

set -e

ENVIRONMENT="${1:-dev}"
NAMESPACE="monitoring"
MINIMAL=false

# Check for --minimal flag
if [[ "$2" == "--minimal" ]] || [[ "$1" == "--minimal" ]]; then
  MINIMAL=true
  echo "Using minimal resource configuration"
fi

echo "Installing monitoring stack for environment: $ENVIRONMENT"
echo "================================================"

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo "✗ kubectl not found. Please install kubectl first."
    echo "  Visit: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "✗ Helm not found. Installing Helm..."
    echo ""
    echo "To install Helm, run one of the following commands:"
    echo ""
    echo "# Using script (Linux/macOS):"
    echo "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    echo ""
    echo "# Using package managers:"
    echo "# Ubuntu/Debian:"
    echo "sudo apt-get install helm"
    echo ""
    echo "# macOS:"
    echo "brew install helm"
    echo ""
    echo "# Windows (Chocolatey):"
    echo "choco install kubernetes-helm"
    echo ""
    exit 1
fi

echo "✓ kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "✓ Helm found: $(helm version --short)"
echo ""

# Create monitoring namespace
echo "Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Determine which values file to use
if [ "$MINIMAL" = true ]; then
  VALUES_FILE="monitoring/prometheus-values-minimal.yaml"
  TIMEOUT="15m"
  echo "Using minimal configuration: $VALUES_FILE"
else
  VALUES_FILE="monitoring/prometheus-values.yaml"
  TIMEOUT="10m"
  echo "Using full configuration: $VALUES_FILE"
fi

# Install Prometheus with Grafana (kube-prometheus-stack)
echo "Installing kube-prometheus-stack..."
echo "This may take several minutes..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace $NAMESPACE \
  --values $VALUES_FILE \
  --create-namespace \
  --timeout $TIMEOUT \
  --wait

# Install Loki for log aggregation (skip if minimal)
if [ "$MINIMAL" = false ]; then
  echo "Installing Loki..."
  helm upgrade --install loki grafana/loki-stack \
    --namespace $NAMESPACE \
    --values monitoring/loki-values.yaml \
    --timeout 10m \
    --wait || echo "⚠ Loki installation failed, continuing..."
fi

# Apply custom Prometheus rules
echo "Applying custom Prometheus alert rules..."
kubectl apply -f monitoring/prometheus/alerts.yaml -n $NAMESPACE

# Create ConfigMap for Grafana dashboards
echo "Creating Grafana dashboard ConfigMap..."
kubectl create configmap grafana-app-dashboards \
  --from-file=monitoring/grafana/dashboards/ \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✓ Monitoring stack installed successfully!"
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-grafana 3000:80"
echo "  Then open: http://localhost:3000"
echo "  Default credentials: admin / changeme"
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  Then open: http://localhost:9090"
echo ""
echo "Access Alertmanager:"
echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-kube-prometheus-alertmanager 9093:9093"
echo "  Then open: http://localhost:9093"
