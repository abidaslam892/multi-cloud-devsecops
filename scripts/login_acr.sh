#!/usr/bin/env bash
set -euo pipefail
ACR_NAME=${1:-$ACR_NAME}
az acr login --name "$ACR_NAME"
