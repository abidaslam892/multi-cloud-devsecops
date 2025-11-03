#!/usr/bin/env bash
set -euo pipefail
AKS_RESOURCE_GROUP=${1:-$AKS_RESOURCE_GROUP}
AKS_CLUSTER_NAME=${2:-$AKS_CLUSTER_NAME}

az aks get-credentials --resource-group "$AKS_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME"
