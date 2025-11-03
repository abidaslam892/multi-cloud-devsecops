#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME=${1:-$EKS_CLUSTER_NAME}
REGION=${2:-$AWS_REGION}

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
