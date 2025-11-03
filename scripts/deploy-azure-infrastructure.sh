#!/bin/bash
# Deploy Azure Infrastructure with Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/azure"

echo "=========================================="
echo "  Azure Infrastructure Deployment"
echo "=========================================="
echo ""

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

echo "✓ Prerequisites checked"
echo ""

# Select environment
read -p "Select environment (dev/stage/prod) [dev]: " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

echo ""
echo "Environment: $ENVIRONMENT"
echo "Terraform directory: $TERRAFORM_DIR"
echo ""

# Check Azure authentication
echo "Checking Azure credentials..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure"
    echo "Run: az login"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)

echo "✓ Azure Subscription: $SUBSCRIPTION_NAME"
echo "✓ Subscription ID: $SUBSCRIPTION_ID"
echo ""

# Create Azure backend if it doesn't exist
STORAGE_ACCOUNT="multicloudtfstate"
CONTAINER_NAME="tfstate"
RESOURCE_GROUP="multi-cloud-terraform-rg"
LOCATION="eastus"

echo "Setting up Terraform backend..."

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "Creating resource group: $RESOURCE_GROUP"
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION"
    echo "✓ Resource group created"
else
    echo "✓ Resource group already exists"
fi

# Check if storage account exists
if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Creating storage account: $STORAGE_ACCOUNT"
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --encryption-services blob \
        --https-only true \
        --min-tls-version TLS1_2
    echo "✓ Storage account created"
else
    echo "✓ Storage account already exists"
fi

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query '[0].value' \
    --output tsv)

# Check if container exists
if ! az storage container show \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" &>/dev/null; then
    echo "Creating storage container: $CONTAINER_NAME"
    az storage container create \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY"
    echo "✓ Storage container created"
else
    echo "✓ Storage container already exists"
fi

echo ""

# Change to Terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init \
    -backend-config="../backends/backend-${ENVIRONMENT}-azure.tfvars" \
    -upgrade

echo ""

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate

echo ""

# Plan deployment
echo "Planning infrastructure changes..."
terraform plan \
    -var="environment=$ENVIRONMENT" \
    -out=tfplan

echo ""
echo "=========================================="
echo "  Review Plan Above"
echo "=========================================="
echo ""

read -p "Apply this plan? [y/N]: " APPLY
if [[ ! "$APPLY" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Applying infrastructure changes..."
terraform apply tfplan

echo ""
echo "=========================================="
echo "  ✅ Azure Infrastructure Deployed!"
echo "=========================================="
echo ""

# Get outputs
echo "Infrastructure Details:"
echo ""
terraform output

echo ""
echo "Next steps:"
echo "  1. Configure kubectl:"
echo "     $(terraform output -raw configure_kubectl)"
echo ""
echo "  2. Verify cluster:"
echo "     kubectl get nodes"
echo ""
echo "  3. Update GitHub Secret AKS_CLUSTER_NAME:"
echo "     gh secret set AKS_CLUSTER_NAME --body \"$(terraform output -raw aks_cluster_name)\""
echo ""
echo "  4. Deploy application:"
echo "     cd ../../helm"
echo "     helm install app ./chart -f values-${ENVIRONMENT}.yaml"
echo ""
