#!/bin/bash
# Login to AWS ECR (Elastic Container Registry)
# 
# Usage:
#   ./scripts/login-ecr.sh [AWS_REGION] [AWS_ACCOUNT_ID]
#
# Environment variables (if args not provided):
#   AWS_REGION - AWS region (default: us-east-1)
#   AWS_ACCOUNT_ID - AWS account ID (required)

set -e

# Set defaults
REGION="${1:-${AWS_REGION:-us-east-1}}"
ACCOUNT_ID="${2:-${AWS_ACCOUNT_ID}}"

# Validate inputs
if [ -z "$ACCOUNT_ID" ]; then
  echo "Error: AWS_ACCOUNT_ID is required"
  echo "Usage: $0 [AWS_REGION] [AWS_ACCOUNT_ID]"
  exit 1
fi

# Construct ECR registry URL
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Logging into ECR registry: $ECR_REGISTRY"

# Login to ECR
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

if [ $? -eq 0 ]; then
  echo "✓ Successfully logged into ECR"
else
  echo "✗ Failed to login to ECR"
  exit 1
fi
