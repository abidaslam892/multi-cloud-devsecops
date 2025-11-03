# Azure GitHub Secrets Configuration Guide

This guide walks you through setting up Azure credentials and configuration for GitHub Actions CI/CD.

## Prerequisites

- Azure Account with appropriate permissions
- Azure CLI installed (`az`)
- GitHub repository admin access
- GitHub CLI (`gh`) installed

## Step 1: Install Azure CLI

### Ubuntu/Debian
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### macOS
```bash
brew install azure-cli
```

### Windows
Download from: https://aka.ms/installazurecliwindows

### Verify Installation
```bash
az --version
```

## Step 2: Login to Azure

```bash
az login
```

This will open a browser window for authentication.

## Step 3: Get Azure Subscription Information

```bash
# List all subscriptions
az account list --output table

# Get current subscription ID
az account show --query id --output tsv

# Set specific subscription (if you have multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

Save your **AZURE_SUBSCRIPTION_ID** - you'll need it later.

## Step 4: Create Service Principal for GitHub Actions

A Service Principal is an identity that GitHub Actions will use to authenticate with Azure.

### 4.1 Set Variables

```bash
# Set your resource group name (use existing or create new)
RESOURCE_GROUP="multi-cloud-rg"
LOCATION="eastus"
SP_NAME="github-actions-sp"

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
```

### 4.2 Create Resource Group (if needed)

```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 4.3 Create Service Principal

```bash
az ad sp create-for-rbac \
  --name $SP_NAME \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  --sdk-auth
```

**IMPORTANT**: Save the entire JSON output! You'll need it for `AZURE_CREDENTIALS`.

Example output:
```json
{
  "clientId": "12345678-1234-1234-1234-123456789012",
  "clientSecret": "your-client-secret-here",
  "subscriptionId": "87654321-4321-4321-4321-210987654321",
  "tenantId": "abcdefgh-1234-5678-90ab-cdefghijklmn",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

## Step 5: Create Azure Container Registry (ACR)

```bash
# Set ACR name (must be globally unique, lowercase alphanumeric only)
ACR_NAME="multicloudacr$(date +%s)"  # Appends timestamp for uniqueness

# Create ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --location $LOCATION

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --query loginServer \
  --output tsv)

echo "ACR Name: $ACR_NAME"
echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

### 5.1 Grant Service Principal Access to ACR

```bash
# Get ACR resource ID
ACR_ID=$(az acr show \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --query id \
  --output tsv)

# Get Service Principal ID
SP_ID=$(az ad sp list \
  --display-name $SP_NAME \
  --query [0].appId \
  --output tsv)

# Assign AcrPush role
az role assignment create \
  --assignee $SP_ID \
  --role AcrPush \
  --scope $ACR_ID
```

## Step 6: Create Azure Kubernetes Service (AKS) Cluster

```bash
# Set AKS cluster name
AKS_CLUSTER_NAME="multi-cloud-aks-dev"

# Create AKS cluster (this takes 5-10 minutes)
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys \
  --location $LOCATION

# Get AKS credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

# Verify cluster access
kubectl get nodes
```

### 6.1 Grant Service Principal Access to AKS

```bash
# Get AKS resource ID
AKS_ID=$(az aks show \
  --name $AKS_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --query id \
  --output tsv)

# Assign Azure Kubernetes Service Cluster User Role
az role assignment create \
  --assignee $SP_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID
```

## Step 7: Prepare GitHub Secrets Values

You need these 7 secrets for GitHub Actions:

### 7.1 AZURE_CREDENTIALS
The entire JSON output from Step 4.3 (Service Principal creation)

### 7.2 AZURE_SUBSCRIPTION_ID
```bash
echo $SUBSCRIPTION_ID
```

### 7.3 AZURE_RESOURCE_GROUP
```bash
echo $RESOURCE_GROUP
```

### 7.4 ACR_NAME
```bash
echo $ACR_NAME
```

### 7.5 ACR_LOGIN_SERVER
```bash
echo $ACR_LOGIN_SERVER
```

### 7.6 ACR_REPO
```bash
echo "multi-cloud-devsecops"
```

### 7.7 AKS_CLUSTER_NAME
```bash
echo $AKS_CLUSTER_NAME
```

## Step 8: Configure GitHub Secrets

### Option A: Via GitHub Web UI

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `AZURE_CREDENTIALS` | Full JSON from Step 4.3 | `{"clientId": "...", ...}` |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID | `87654321-4321-4321-4321-210987654321` |
| `AZURE_RESOURCE_GROUP` | Resource group name | `multi-cloud-rg` |
| `ACR_NAME` | ACR name | `multicloudacr1730678400` |
| `ACR_LOGIN_SERVER` | ACR login server | `multicloudacr1730678400.azurecr.io` |
| `ACR_REPO` | Repository name | `multi-cloud-devsecops` |
| `AKS_CLUSTER_NAME` | AKS cluster name | `multi-cloud-aks-dev` |

### Option B: Via GitHub CLI (Automated)

```bash
# Set variables (replace with your actual values)
AZURE_CREDENTIALS='{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}'
AZURE_SUBSCRIPTION_ID="your-subscription-id"
AZURE_RESOURCE_GROUP="multi-cloud-rg"
ACR_NAME="multicloudacr1730678400"
ACR_LOGIN_SERVER="multicloudacr1730678400.azurecr.io"
ACR_REPO="multi-cloud-devsecops"
AKS_CLUSTER_NAME="multi-cloud-aks-dev"

# Set secrets
gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS"
gh secret set AZURE_SUBSCRIPTION_ID --body "$AZURE_SUBSCRIPTION_ID"
gh secret set AZURE_RESOURCE_GROUP --body "$AZURE_RESOURCE_GROUP"
gh secret set ACR_NAME --body "$ACR_NAME"
gh secret set ACR_LOGIN_SERVER --body "$ACR_LOGIN_SERVER"
gh secret set ACR_REPO --body "$ACR_REPO"
gh secret set AKS_CLUSTER_NAME --body "$AKS_CLUSTER_NAME"
```

### Option C: Automated Script

Use the provided script:
```bash
./scripts/setup-azure-secrets.sh
```

## Step 9: Verify Setup

### 9.1 Test Azure CLI Access

```bash
# Test authentication
az account show

# Test ACR login
az acr login --name $ACR_NAME

# Test AKS access
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

kubectl get nodes
```

### 9.2 Verify GitHub Secrets

```bash
gh secret list
```

You should see all 7 Azure secrets + 6 AWS secrets = 13 total secrets.

## Step 10: Test CI/CD Pipeline

```bash
# Make a small change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test Azure CI/CD pipeline"
git push origin main
```

Monitor the GitHub Actions workflow at:
`https://github.com/YOUR_USERNAME/multi-cloud-devsecops/actions`

## Troubleshooting

### Issue: "Service principal not found"

**Solution**: Wait a few minutes for Azure AD propagation, then retry.

### Issue: "ACR name already exists"

**Solution**: ACR names must be globally unique. Use a different name:
```bash
ACR_NAME="yourname-multicloud-acr"
```

### Issue: "Insufficient permissions"

**Solution**: Ensure you have Owner or Contributor role on the subscription:
```bash
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

### Issue: "AKS creation failed"

**Solution**: Check quota limits:
```bash
az vm list-usage --location eastus --output table
```

### Issue: "kubectl: command not found"

**Solution**: Install kubectl:
```bash
az aks install-cli
```

## Security Best Practices

1. **Rotate Service Principal Secrets**: Set up regular rotation (90 days)
2. **Use Managed Identities**: For production, consider using managed identities
3. **Limit RBAC Scope**: Grant least privilege access
4. **Enable Azure AD Integration**: For AKS authentication
5. **Use Azure Key Vault**: For storing sensitive configuration

## Cost Optimization

For development/testing:
- Use **Basic** SKU for ACR (~$5/month)
- Use **Standard_B2s** VMs for AKS nodes (~$30/month per node)
- Delete resources when not in use:
  ```bash
  az group delete --name $RESOURCE_GROUP --yes --no-wait
  ```

## Quick Reference

```bash
# Login to Azure
az login

# Get subscription ID
az account show --query id -o tsv

# List resource groups
az group list --output table

# List ACRs
az acr list --output table

# List AKS clusters
az aks list --output table

# Test ACR login
az acr login --name $ACR_NAME

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Delete resource group (cleanup)
az group delete --name $RESOURCE_GROUP --yes
```

## Summary Checklist

After completing this guide, you should have:

- ✅ Azure CLI installed and authenticated
- ✅ Service Principal created with appropriate permissions
- ✅ Azure Container Registry (ACR) created
- ✅ Azure Kubernetes Service (AKS) cluster created
- ✅ All 7 GitHub Secrets configured:
  - AZURE_CREDENTIALS
  - AZURE_SUBSCRIPTION_ID
  - AZURE_RESOURCE_GROUP
  - ACR_NAME
  - ACR_LOGIN_SERVER
  - ACR_REPO
  - AKS_CLUSTER_NAME
- ✅ Verified access to ACR and AKS

**Next Step**: Push code to trigger CI/CD pipeline and deploy to both AWS and Azure!
