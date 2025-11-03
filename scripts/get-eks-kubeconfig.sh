#!/bin/bash
# Fetch kubeconfig for AWS EKS cluster
#
# Usage:
#   ./scripts/fetch-kubeconfig.sh [CLUSTER_NAME] [AWS_REGION]
#
# Environment variables (if args not provided):
#   EKS_CLUSTER_NAME - EKS cluster name (required)
#   AWS_REGION - AWS region (default: us-east-1)
#   KUBECONFIG - Path to kubeconfig file (default: ~/.kube/config)

set -e

# Set defaults
CLUSTER_NAME="${1:-${EKS_CLUSTER_NAME}}"
REGION="${2:-${AWS_REGION:-us-east-1}}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

# Validate inputs
if [ -z "$CLUSTER_NAME" ]; then
  echo "Error: EKS_CLUSTER_NAME is required"
  echo "Usage: $0 [CLUSTER_NAME] [AWS_REGION]"
  exit 1
fi

echo "Fetching kubeconfig for EKS cluster: $CLUSTER_NAME in region: $REGION"

# Update kubeconfig for EKS cluster
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --kubeconfig "$KUBECONFIG_PATH"

if [ $? -eq 0 ]; then
  echo "✓ Successfully configured kubectl for EKS cluster: $CLUSTER_NAME"
  echo "  Kubeconfig location: $KUBECONFIG_PATH"
  echo ""
  echo "Verify connection:"
  echo "  kubectl get nodes"
else
  echo "✗ Failed to fetch EKS kubeconfig"
  exit 1
fi
