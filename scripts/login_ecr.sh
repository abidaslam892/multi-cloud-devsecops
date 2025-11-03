#!/usr/bin/env bash
set -euo pipefail
REGION=${1:-us-east-1}
ECR_REGISTRY=${2:-${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com}

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
