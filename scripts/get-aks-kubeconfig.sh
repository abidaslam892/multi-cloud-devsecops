#!/bin/bash
# Fetch kubeconfig for Azure AKS cluster
#
# Usage:
#   ./scripts/fetch-kubeconfig.sh [CLUSTER_NAME] [RESOURCE_GROUP] [SUBSCRIPTION_ID]
#
# Environment variables (if args not provided):
#   AKS_CLUSTER_NAME - AKS cluster name (required)
#   RESOURCE_GROUP - Azure resource group (required)
#   AZURE_SUBSCRIPTION_ID - Azure subscription ID (optional)
#   KUBECONFIG - Path to kubeconfig file (default: ~/.kube/config)

set -e

# Set defaults
CLUSTER_NAME="${1:-${AKS_CLUSTER_NAME}}"
RESOURCE_GROUP="${2:-${RESOURCE_GROUP}}"
SUBSCRIPTION_ID="${3:-${AZURE_SUBSCRIPTION_ID}}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

# Validate inputs
if [ -z "$CLUSTER_NAME" ]; then
  echo "Error: AKS_CLUSTER_NAME is required"
  echo "Usage: $0 [CLUSTER_NAME] [RESOURCE_GROUP] [SUBSCRIPTION_ID]"
  exit 1
fi

if [ -z "$RESOURCE_GROUP" ]; then
  echo "Error: RESOURCE_GROUP is required"
  echo "Usage: $0 [CLUSTER_NAME] [RESOURCE_GROUP] [SUBSCRIPTION_ID]"
  exit 1
fi

# Set subscription if provided
if [ -n "$SUBSCRIPTION_ID" ]; then
  echo "Setting Azure subscription: $SUBSCRIPTION_ID"
  az account set --subscription "$SUBSCRIPTION_ID"
fi

echo "Fetching kubeconfig for AKS cluster: $CLUSTER_NAME in resource group: $RESOURCE_GROUP"

# Get AKS credentials
az aks get-credentials \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --file "$KUBECONFIG_PATH" \
  --overwrite-existing

if [ $? -eq 0 ]; then
  echo "✓ Successfully configured kubectl for AKS cluster: $CLUSTER_NAME"
  echo "  Kubeconfig location: $KUBECONFIG_PATH"
  echo ""
  echo "Verify connection:"
  echo "  kubectl get nodes"
else
  echo "✗ Failed to fetch AKS kubeconfig"
  exit 1
fi
