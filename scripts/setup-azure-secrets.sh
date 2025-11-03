#!/bin/bash
# Setup Azure GitHub Secrets Interactively
# This script helps configure all required Azure secrets for GitHub Actions

set -e

echo "=========================================="
echo "  Azure GitHub Secrets Setup Wizard"
echo "=========================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed"
    echo ""
    echo "Install it with:"
    echo "  Ubuntu/Debian: sudo apt install gh"
    echo "  macOS: brew install gh"
    echo "  Or visit: https://cli.github.com/"
    echo ""
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Error: Azure CLI (az) is not installed"
    echo ""
    echo "Install it with:"
    echo "  Ubuntu/Debian: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    echo "  macOS: brew install azure-cli"
    echo "  Or visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    echo ""
    exit 1
fi

# Check if user is authenticated to GitHub
if ! gh auth status &> /dev/null; then
    echo "🔐 GitHub CLI authentication required"
    gh auth login
fi

# Check if user is authenticated to Azure
if ! az account show &> /dev/null 2>&1; then
    echo "🔐 Azure CLI authentication required"
    az login
fi

echo "✓ GitHub CLI is ready"
echo "✓ Azure CLI is ready"
echo ""

# Get Azure subscription
echo "Step 1: Azure Subscription"
echo "--------------------------"
echo "Available subscriptions:"
az account list --query "[].{Name:name, ID:id, State:state}" --output table
echo ""

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Current subscription: $SUBSCRIPTION_ID"
read -p "Use this subscription? [Y/n]: " USE_CURRENT
if [[ "$USE_CURRENT" =~ ^[Nn]$ ]]; then
    read -p "Enter Subscription ID: " SUBSCRIPTION_ID
    az account set --subscription "$SUBSCRIPTION_ID"
fi
echo ""

# Resource Group
echo "Step 2: Resource Group"
echo "----------------------"
echo "Existing resource groups:"
az group list --query "[].{Name:name, Location:location}" --output table 2>/dev/null || echo "No resource groups found"
echo ""

read -p "Enter Resource Group name [multi-cloud-rg]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-multi-cloud-rg}

read -p "Enter Azure Region [eastus]: " LOCATION
LOCATION=${LOCATION:-eastus}

# Check if resource group exists
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo "✓ Resource group '$RESOURCE_GROUP' exists"
else
    echo "Creating resource group '$RESOURCE_GROUP' in $LOCATION..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    echo "✓ Resource group created"
fi
echo ""

# Service Principal
echo "Step 3: Service Principal"
echo "-------------------------"
SP_NAME="github-actions-sp-$(date +%s)"
echo "Creating Service Principal: $SP_NAME"
echo "(This will be used by GitHub Actions to authenticate with Azure)"
echo ""

SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role contributor \
    --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
    --sdk-auth 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✓ Service Principal created"
    AZURE_CREDENTIALS="$SP_OUTPUT"
    SP_APP_ID=$(echo "$SP_OUTPUT" | jq -r '.clientId')
else
    echo "❌ Failed to create Service Principal"
    exit 1
fi
echo ""

# ACR (Azure Container Registry)
echo "Step 4: Azure Container Registry (ACR)"
echo "---------------------------------------"
echo "Existing ACRs:"
az acr list --query "[].{Name:name, Location:location, LoginServer:loginServer}" --output table 2>/dev/null || echo "No ACRs found"
echo ""

read -p "Do you want to create a new ACR? [Y/n]: " CREATE_ACR
if [[ ! "$CREATE_ACR" =~ ^[Nn]$ ]]; then
    ACR_NAME_DEFAULT="multicloudacr$(date +%s | tail -c 6)"
    read -p "Enter ACR name [$ACR_NAME_DEFAULT] (lowercase alphanumeric only): " ACR_NAME_INPUT
    ACR_NAME=${ACR_NAME_INPUT:-$ACR_NAME_DEFAULT}
    
    echo "Creating ACR: $ACR_NAME..."
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku Basic \
        --location "$LOCATION" \
        --output none
    
    if [ $? -eq 0 ]; then
        echo "✓ ACR created"
        
        # Grant SP access to ACR
        echo "Granting Service Principal access to ACR..."
        ACR_ID=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id --output tsv)
        az role assignment create \
            --assignee "$SP_APP_ID" \
            --role AcrPush \
            --scope "$ACR_ID" \
            --output none
        echo "✓ Access granted"
    else
        echo "❌ Failed to create ACR"
        exit 1
    fi
else
    read -p "Enter existing ACR name: " ACR_NAME
fi

ACR_LOGIN_SERVER=$(az acr show \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query loginServer \
    --output tsv)

ACR_REPO="multi-cloud-devsecops"
echo "✓ ACR configured: $ACR_LOGIN_SERVER"
echo ""

# AKS (Azure Kubernetes Service)
echo "Step 5: Azure Kubernetes Service (AKS)"
echo "---------------------------------------"
echo "Existing AKS clusters:"
az aks list --query "[].{Name:name, Location:location, NodeCount:agentPoolProfiles[0].count}" --output table 2>/dev/null || echo "No AKS clusters found"
echo ""

read -p "Do you want to create a new AKS cluster? [y/N]: " CREATE_AKS
if [[ "$CREATE_AKS" =~ ^[Yy]$ ]]; then
    read -p "Enter AKS cluster name [multi-cloud-aks-dev]: " AKS_CLUSTER_INPUT
    AKS_CLUSTER_NAME=${AKS_CLUSTER_INPUT:-multi-cloud-aks-dev}
    
    echo ""
    echo "⏳ Creating AKS cluster: $AKS_CLUSTER_NAME"
    echo "   This will take 5-10 minutes..."
    echo ""
    
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --node-count 2 \
        --node-vm-size Standard_B2s \
        --enable-managed-identity \
        --attach-acr "$ACR_NAME" \
        --generate-ssh-keys \
        --location "$LOCATION" \
        --output none
    
    if [ $? -eq 0 ]; then
        echo "✓ AKS cluster created"
        
        # Grant SP access to AKS
        echo "Granting Service Principal access to AKS..."
        AKS_ID=$(az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query id --output tsv)
        az role assignment create \
            --assignee "$SP_APP_ID" \
            --role "Azure Kubernetes Service Cluster User Role" \
            --scope "$AKS_ID" \
            --output none
        echo "✓ Access granted"
    else
        echo "❌ Failed to create AKS cluster"
        exit 1
    fi
else
    read -p "Enter existing AKS cluster name: " AKS_CLUSTER_NAME
fi
echo ""

# Summary
echo "=========================================="
echo "  Configuration Summary"
echo "=========================================="
echo ""
echo "AZURE_SUBSCRIPTION_ID:  $SUBSCRIPTION_ID"
echo "AZURE_RESOURCE_GROUP:   $RESOURCE_GROUP"
echo "ACR_NAME:               $ACR_NAME"
echo "ACR_LOGIN_SERVER:       $ACR_LOGIN_SERVER"
echo "ACR_REPO:               $ACR_REPO"
echo "AKS_CLUSTER_NAME:       $AKS_CLUSTER_NAME"
echo "AZURE_CREDENTIALS:      (JSON - hidden)"
echo ""

read -p "Proceed to set GitHub Secrets? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Cancelled."
    echo ""
    echo "IMPORTANT: Save this Service Principal JSON for AZURE_CREDENTIALS:"
    echo "$AZURE_CREDENTIALS"
    exit 0
fi

echo ""
echo "Setting GitHub Secrets..."
echo ""

# Set secrets
gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS"
echo "✓ AZURE_CREDENTIALS set"

gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
echo "✓ AZURE_SUBSCRIPTION_ID set"

gh secret set AZURE_RESOURCE_GROUP --body "$RESOURCE_GROUP"
echo "✓ AZURE_RESOURCE_GROUP set"

gh secret set ACR_NAME --body "$ACR_NAME"
echo "✓ ACR_NAME set"

gh secret set ACR_LOGIN_SERVER --body "$ACR_LOGIN_SERVER"
echo "✓ ACR_LOGIN_SERVER set"

gh secret set ACR_REPO --body "$ACR_REPO"
echo "✓ ACR_REPO set"

if [ -n "$AKS_CLUSTER_NAME" ]; then
    gh secret set AKS_CLUSTER_NAME --body "$AKS_CLUSTER_NAME"
    echo "✓ AKS_CLUSTER_NAME set"
else
    echo "⚠ AKS_CLUSTER_NAME skipped (no cluster name provided)"
fi

echo ""
echo "=========================================="
echo "  ✅ All Azure Secrets Configured!"
echo "=========================================="
echo ""
echo "Verify secrets with: gh secret list"
echo ""
echo "Next steps:"
echo "  1. Test AKS access:"
echo "     az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME"
echo "     kubectl get nodes"
echo ""
echo "  2. Push code to trigger CI/CD pipeline:"
echo "     git push origin main"
echo ""
echo "  3. Monitor deployment:"
echo "     https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
echo ""
