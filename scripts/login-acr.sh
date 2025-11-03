#!/bin/bash
# Login to Azure Container Registry (ACR)
#
# Usage:
#   ./scripts/login-acr.sh [ACR_NAME]
#
# Environment variables (if args not provided):
#   ACR_NAME - Azure Container Registry name (required)

set -e

# Get ACR name from argument or environment variable
ACR_NAME="${1:-${ACR_NAME}}"

# Validate inputs
if [ -z "$ACR_NAME" ]; then
  echo "Error: ACR_NAME is required"
  echo "Usage: $0 [ACR_NAME]"
  exit 1
fi

echo "Logging into ACR: $ACR_NAME"

# Login to ACR
az acr login --name "$ACR_NAME"

if [ $? -eq 0 ]; then
  echo "✓ Successfully logged into ACR: ${ACR_NAME}.azurecr.io"
else
  echo "✗ Failed to login to ACR"
  exit 1
fi
